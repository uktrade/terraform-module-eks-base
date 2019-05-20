provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

resource "tls_private_key" "portus-tls-key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_self_signed_cert" "portus-tls-cert" {
  key_algorithm = "${tls_private_key.portus-tls-key.algorithm}"
  private_key_pem = "${tls_private_key.portus-tls-key.private_key_pem}"
  subject {
    common_name = "registry.${var.cluster_domain}"
  }
  validity_period_hours = 87600
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "data_encipherment",
    "server_auth",
    "client_auth",
    "any_extended"
  ]
}

data "template_file" "registry-values" {
  template = <<EOF
storage: s3
s3:
  region: ${var.registry_config["s3_region"]}
  bucket: ${var.registry_config["s3_bucket"]}
  encrypt: true
  secure: true
secrets:
  s3:
    accessKey: ${var.registry_config["s3_accesskey"]}
    secretKey: ${var.registry_config["s3_secretkey"]}
persistence:
  deleteEnabled: true
configData:
  version: 0.1
  health:
    storagedriver:
      enabled: true
      interval: 10s
      threshold: 3
  http:
    addr: :5000
    headers:
      X-Content-Type-Options:
      - nosniff
  log:
    fields:
      service: registry
  storage:
    cache:
      blobdescriptor: inmemory
    delete:
      enabled: true
    maintenance:
      uploadpurging:
        enabled: true
        age: 168h
        interval: 24h
        dryrun: false
      readonly:
        enabled: false
  auth:
    token:
      realm: https://registry.${var.cluster_domain}/console/v2/token
      service: registry.${var.cluster_domain}
      issuer: registry.${var.cluster_domain}
      rootcertbundle: /secrets/cert.pem
  notifications:
    endpoints:
      - name: portus
        url: https://registry.ci.uktrade.io/console/v2/webhooks/events
        timeout: 500ms
        threshold: 5
        backoff: 1s
EOF
}

resource "helm_release" "registry" {
  name = "docker-registry"
  namespace = "default"
  repository = "stable"
  chart = "docker-registry"
  version = "1.8.0"
  values = ["${data.template_file.registry-values.rendered}"]
}

data "template_file" "registry-portus-patch" {
  template = <<EOF
spec:
  template:
    spec:
      volumes:
      - name: ca-bundle
        secret:
          secretName: portus-secrets
          defaultMode: 420
          items:
          - key: PORTUS_CERT
            path: cert.pem
      containers:
      - name: docker-registry
        volumeMounts:
        - name: ca-bundle
          mountPath: /secrets
          readOnly: true
EOF
}

resource "null_resource" "registry-portus-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n default patch deployment docker-registry -p '${data.template_file.registry-portus-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "kubernetes_config_map" "portus-config" {
  metadata {
    name = "portus-config"
    namespace = "default"
  }
  data {
    PORTUS_DB_HOST = "${var.registry_config["db_host"]}"
    PORTUS_DB_DATABASE = "${var.registry_config["db_name"]}"
    PORTUS_DB_USERNAME = "${var.registry_config["db_user"]}"
    PORTUS_DB_PASSWORD = "${var.registry_config["db_password"]}"
    config.yml = <<EOF
machine_fqdn:
  value: registry.${var.cluster_domain}
check_ssl_usage:
  enabled: false
oauth:
  github:
    enabled: true
    client_id: "${var.registry_config["oauth_client_id"]}"
    client_secret: "${var.registry_config["oauth_client_secret"]}"
    organization: "${var.registry_config["oauth_organization"]}"
    team: "${var.registry_config["oauth_team"]}"
registry:
  jwt_expiration_time:
    value: 3600
  timeout:
    value: 2
  read_timeout:
    value: 180
  catalog_page:
    value: 100
delete:
  enabled: true
  contributors: true
  garbage_collector:
    enabled: true
    older_than: 180
    tag: ''
background:
  registry:
    enabled: true
  sync:
    enabled: true
    strategy: update-delete
security:
  clair:
    server: ''
    health_port: 6061
    timeout: 900
user_permission:
  change_visibility:
    enabled: true
  create_team:
    enabled: true
  manage_team:
    enabled: true
  create_namespace:
    enabled: true
  manage_namespace:
    enabled: true
  create_webhook:
    enabled: true
  manage_webhook:
    enabled: true
  push_images:
    policy: allow-teams
anonymous_browsing:
  enabled: true
first_user_admin:
  enabled: true
signup:
  enabled: false
display_name:
  enabled: true
gravatar:
  enabled: true
EOF
  }
}

resource "kubernetes_secret" "portus-secret" {
  metadata {
    name = "portus-secrets"
    namespace = "default"
  }
  data {
    PORTUS_CERT = "${tls_self_signed_cert.portus-tls-cert.cert_pem}"
    PORTUS_KEY = "${tls_private_key.portus-tls-key.private_key_pem}"
    PORTUS_PASSWORD = "${var.registry_config["default_password"]}"
    PORTUS_SECRET_KEY_BASE = "${var.registry_config["secret_key_base"]}"
  }
}

data "template_file" "portus" {
  template = "${file("${path.module}/portus-dc.yaml")}"
  vars = {
    version = "${var.registry_config["version"]}"
  }
}

resource "null_resource" "portus" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n default apply -f -
${data.template_file.portus.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "kubernetes_service" "portus" {
  metadata {
    name = "portus"
    namespace = "default"
  }
  spec {
    selector {
      app = "portus"
    }
    type = "ClusterIP"
    port {
      name = "http"
      protocol = "TCP"
      port = 3000
      target_port = 3000
    }
  }
}

data "template_file" "portus-ingress" {
  template = <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /console/$$request_uri
  labels:
    app: portus
  name: portus
spec:
  rules:
  - host: registry.${var.cluster_domain}
    http:
      paths:
      - backend:
          serviceName: portus
          servicePort: 3000
        path: /(assets|favicon)/
EOF
}

data "template_file" "docker-registry-ingress" {
  template = <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: portus
  name: docker-registry
spec:
  rules:
  - host: registry.${var.cluster_domain}
    http:
      paths:
      - backend:
          serviceName: docker-registry
          servicePort: 5000
        path: /
      - backend:
          serviceName: portus
          servicePort: 3000
        path: /console/
EOF
}

resource "null_resource" "portus-ingress" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n default apply -f -
${data.template_file.portus-ingress.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "docker-registry-ingress" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n default apply -f -
${data.template_file.docker-registry-ingress.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
