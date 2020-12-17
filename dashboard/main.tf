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
  values = [data.template_file.metrics-server-values.rendered]
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
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - "console.${var.eks_extra_config["domain"]}"
  path: /oauth2
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "oauth-proxy" {
  name = "oauth2-proxy"
  namespace = "kube-system"
  repository = "cloudposse"
  chart = "oauth2-proxy"
  version = var.helm_release["oauth2-proxy"]
  values = [data.template_file.oauth-proxy-values.rendered]
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
protocolHttp: true
metricsScraper:
  enabled: true
extraArgs:
  - --enable-skip-login
  - --enable-insecure-login
  - --disable-settings-authorizer
ingress:
  enabled: true
  hosts:
    - "console.${var.eks_extra_config["domain"]}"
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
  repository = "kubernetes-dashboard"
  chart = "kubernetes-dashboard"
  version = var.helm_release["kubernetes-dashboard"]
  values = [data.template_file.dashboard-values.rendered]
  depends_on = [kubernetes_cluster_role_binding.dashboard-admin]
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
