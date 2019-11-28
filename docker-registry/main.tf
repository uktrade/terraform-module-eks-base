resource "kubernetes_namespace" "tools" {
  metadata {
    name = "tools"
  }
}

resource "tls_private_key" "portus-tls-key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_self_signed_cert" "portus-tls-cert" {
  key_algorithm = tls_private_key.portus-tls-key.algorithm
  private_key_pem = tls_private_key.portus-tls-key.private_key_pem
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

resource "kubernetes_secret" "docker-registry-cert" {
  metadata {
    name = "docker-registry-cert"
    namespace = "tools"
  }
  data = {
    "tls.crt" = tls_self_signed_cert.portus-tls-cert.cert_pem
    "tls.key" = tls_private_key.portus-tls-key.private_key_pem
  }
}

data "template_file" "registry-values" {
  template = <<EOF
storage: s3
s3:
  region: ${var.registry_config["s3_region"]}
  bucket: ${var.registry_config["s3_bucket"]}
  encrypt: true
  secure: true
tlsSecretName: docker-registry-cert
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
      rootcertbundle: /etc/ssl/docker/tls.crt
  notifications:
    endpoints:
      - name: portus
        url: https://registry.${var.cluster_domain}/console/v2/webhooks/events
        timeout: 500ms
        threshold: 5
        backoff: 1s
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "registry" {
  name = "docker-registry"
  namespace = "tools"
  repository = "stable"
  chart = "docker-registry"
  version = var.helm_release["docker-registry"]
  values = ["${data.template_file.registry-values.rendered}"]
  depends_on = [tls_self_signed_cert.portus-tls-cert]
}

resource "kubernetes_config_map" "portus-config" {
  metadata {
    name = "portus-config"
    namespace = "tools"
  }
  data = {
    PORTUS_DB_HOST = var.registry_config["db_host"]
    PORTUS_DB_DATABASE = var.registry_config["db_name"]
    PORTUS_DB_USERNAME = var.registry_config["db_user"]
    PORTUS_DB_PASSWORD = var.registry_config["db_password"]
    "config.yml" = templatefile("${path.module}/portus-config.tmpl", { cluster_domain = "${var.cluster_domain}", oauth_client_id = "${var.registry_config["oauth_client_id"]}", oauth_client_secret = "${var.registry_config["oauth_client_secret"]}", oauth_organization = "${var.registry_config["oauth_organization"]}", oauth_team = "${var.registry_config["oauth_team"]}" })
  }
}

resource "kubernetes_secret" "portus-secret" {
  metadata {
    name = "portus-secrets"
    namespace = "tools"
  }
  data = {
    PORTUS_CERT = tls_self_signed_cert.portus-tls-cert.cert_pem
    PORTUS_KEY = tls_private_key.portus-tls-key.private_key_pem
    PORTUS_PASSWORD = var.registry_config["default_password"]
    PORTUS_SECRET_KEY_BASE = var.registry_config["secret_key_base"]
  }
}

data "template_file" "portus" {
  template = "${file("${path.module}/portus-dc.yaml")}"
  vars = {
    version = "${var.registry_config["portus_version"]}"
  }
  depends_on = [kubernetes_secret.portus-secret]
}

resource "null_resource" "portus" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n tools apply -f -
${data.template_file.portus.rendered}
EOL
EOF
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.template_file.portus.rendered)
  }
  depends_on = [kubernetes_secret.portus-secret]
}

resource "kubernetes_service" "portus" {
  metadata {
    name = "portus"
    namespace = "tools"
  }
  spec {
    selector = {
      app = "portus"
    }
    type = "ClusterIP"
    port  {
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
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /console/\$$request_uri
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
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
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
cat <<EOL | kubectl -n tools apply -f -
${data.template_file.portus-ingress.rendered}
EOL
EOF
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.template_file.portus-ingress.rendered)
  }
}

resource "null_resource" "docker-registry-ingress" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n tools apply -f -
${data.template_file.docker-registry-ingress.rendered}
EOL
EOF
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.template_file.docker-registry-ingress.rendered)
  }
}
