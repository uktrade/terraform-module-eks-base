#
# Configure and setup Kubernetes Dashboard with oauth proxy using Github OAuth
# Docs: https://github.com/kubernetes/dashboard/tree/master/aio/deploy/helm-chart/kubernetes-dashboard
#

data "template_file" "oauth-proxy-values" {
  template = <<EOF
image:
  repository: quay.io/oauth2-proxy/oauth2-proxy
  tag: "${var.dashboard_oauth_config["oauth2_proxy_version"]}"
config:
  clientID: "${var.dashboard_oauth_config["client_id"]}"
  clientSecret: "${var.dashboard_oauth_config["client_secret"]}"
  cookieSecret: "${var.dashboard_oauth_config["cookie_secret"]}"
  configFile: |-
    provider = "${var.dashboard_oauth_config["provider"]}"
    github_org = "${var.dashboard_oauth_config["github_org"]}"
    github_team = "${var.dashboard_oauth_config["github_team"]}"
    cookie_refresh = 60
    cookie_secure = true
    pass_access_token = true
    reverse_proxy = true
    upstreams = ["https://console.${var.eks_extra_config["domain"]}/"]
extraArgs:
  silence-ping-logging: true
  email-domain: "*"
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - "console.${var.eks_extra_config["domain"]}"
  path: /oauth2
EOF
}

resource "helm_release" "oauth-proxy" {
  name = "oauth2-proxy"
  namespace = "kube-system"
  repository = "https://charts.helm.sh/stable"
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
metrics-server:
  enabled: true
  args:
    - --kubelet-preferred-address-types=InternalIP
extraArgs:
  - --enable-skip-login
  - --enable-insecure-login
  - --disable-settings-authorizer
settings:
  clusterName: ${var.cluster_name}
  itemsPerPage: 10
  logsAutoRefreshTimeInterval: 5
  resourceAutoRefreshTimeInterval: 5
  disableAccessDeniedNotifications: false
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
EOF
}

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "https://kubernetes.github.io/dashboard"
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
