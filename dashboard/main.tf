provider "kubernetes" {
  config_path = var.kubeconfig_filename
}

data "template_file" "metrics-server-values" {
  template = <<EOF
args:
  - --kubelet-preferred-address-types=InternalIP
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "metrics-server" {
  name = "metrics-server"
  namespace = "kube-system"
  repository = "stable"
  chart = "metrics-server"
  version = var.helm_release["metrics-server"]
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
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "oauth-proxy" {
  name = "oauth2-proxy"
  namespace = "kube-system"
  repository = "stable"
  chart = "oauth2-proxy"
  version = var.helm_release["oauth2-proxy"]
  values = ["${data.template_file.oauth-proxy-values.rendered}"]
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
    kubernetes.io/ingress.class: nginx
    kubernetes.io/ingress.allow-http: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "stable"
  chart = "kubernetes-dashboard"
  version = var.helm_release["kubernetes-dashboard"]
  values = ["${data.template_file.dashboard-values.rendered}"]
  depends_on = [kubernetes_cluster_role_binding.dashboard-admin]
}

# Terraform has no Ingress resource support yet
data "template_file" "dashboard-oauth" {
  template = <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dashboard-oauth2
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
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
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.template_file.dashboard-oauth.rendered)
  }
  depends_on = [helm_release.metrics-server, helm_release.oauth-proxy, helm_release.dashboard]
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
