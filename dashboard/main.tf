provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

data "template_file" "metrics-server-values" {
  template = <<EOF
args:
  - --kubelet-preferred-address-types=InternalIP
EOF
}

resource "helm_release" "metrics-server" {
  name = "metrics-server"
  namespace = "kube-system"
  repository = "stable"
  chart = "metrics-server"
  values = ["${data.template_file.metrics-server-values.rendered}"]
}

data "template_file" "oauth-proxy-values" {
  template = <<EOF
config:
  clientID: "${var.dashboard_oauth_config["client_id"]}"
  clientSecret: "${var.dashboard_oauth_config["client_secret"]}"
  cookieSecret: "${var.dashboard_oauth_config["cookie_secret"]}"
  configFile: |-
    provider = "${var.dashboard_oauth_config["provider"]}"
    github_org = "${var.dashboard_oauth_config["github_org"]}"
    github_team = "${var.dashboard_oauth_config["github_team"]}"
    email_domains = ["*"]
    cookie_refresh = 60
    pass_access_token = true
    upstream = "file:///dev/null"
EOF
}

resource "helm_release" "oauth-proxy" {
  name = "oauth2-proxy"
  namespace = "kube-system"
  repository = "stable"
  chart = "oauth2-proxy"
  values = ["${data.template_file.oauth-proxy-values.rendered}"]
}

data "template_file" "dashboard-values" {
  template = <<EOF
enableInsecureLogin: true
enableSkipLogin: true
extraArgs:
  - --disable-settings-authorizer
service:
  externalPort: 8080
  internalPort: 8080
ingress:
  enabled: true
  hosts:
    - "console.${var.cluster_domain}"
  annotations:
    kubernetes.io/ingress.allow-http: "false"
    nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
EOF
}

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "stable"
  chart = "kubernetes-dashboard"
  values = ["${data.template_file.dashboard-values.rendered}"]
}

# Terraform has no Ingress resource support yet
data "template_file" "dashboard-oauth" {
  template = <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dashboard-oauth2
spec:
  rules:
  - host: "console.${var.cluster_domain}"
    http:
      paths:
      - path: /oauth2
        backend:
          serviceName: oauth2-proxy
          servicePort: 80
EOF
}

resource "null_resource" "dashboard-oauth" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system apply -f -
${data.template_file.dashboard-oauth.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "kubernetes_service_account" "eks-admin" {
  metadata {
    name = "eks-admin"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "eks-admin" {
  metadata {
    name = "eks-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "eks-admin"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "dashboard-admin" {
  metadata {
    name = "kubernetes-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "kubernetes-dashboard"
    namespace = "kube-system"
  }
}

module "eks-admin-token" {
  source  = "matti/resource/shell"
  command = "KUBECONFIG=${var.kubeconfig_filename} kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}'"
}

data "kubernetes_secret" "eks-admin-token" {
  metadata {
    name = "${module.eks-admin-token.stdout}"
    namespace = "kube-system"
  }
}

output "eks-admin-token" {
  value = "${data.kubernetes_secret.eks-admin-token.data}"
}

# Known Bug: https://github.com/terraform-providers/terraform-provider-kubernetes/issues/334
data "template_file" "dashboard-kubeconfig" {
  template = <<EOF
apiVersion: v1
kind: Config
preferences: {}
current-context: v3-uktrade-io
clusters:
- name: ${var.cluster_id}
  cluster:
    certificate-authority-data: ${var.cluster_ca_certificate}
    server: https://kubernetes.default
contexts:
- name: ${var.cluster_id}
  context:
    cluster: ${var.cluster_id}
    user: ${var.cluster_id}
users:
- name: ${var.cluster_id}
  user:
    token: ${lookup(data.kubernetes_secret.eks-admin-token.data, "token")}
EOF
}

resource "kubernetes_secret" "dashboard-kubeconfig" {
  metadata {
    name = "kubernetes-dashboard-kubeconfig"
    namespace = "kube-system"
  }
  data {
    kubeconfig = "${data.template_file.dashboard-kubeconfig.rendered}"
  }
}

data "template_file" "dashboard-kubeconfig-patch" {
  template = <<EOF
spec:
  template:
    spec:
      volumes:
      - name: kubernetes-dashboard-kubeconfig
        secret:
          secretName: kubernetes-dashboard-kubeconfig
          defaultMode: 422
          items:
          - key: kubeconfig
            path: config
            mode: 422
      containers:
        - name: kubernetes-dashboard
          env:
          - name: KUBECONFIG
            value: /.kube/config
          volumeMounts:
          - name: kubernetes-dashboard-kubeconfig
            mountPath: /.kube
EOF
}

resource "null_resource" "dashboard-kubeconfig-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system patch deployment kubernetes-dashboard -p '${data.template_file.dashboard-kubeconfig-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
