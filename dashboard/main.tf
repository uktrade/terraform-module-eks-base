data "template_file" "metrics-server-values" {
  template = <<EOF
extraArgs:
  kubelet-preferred-address-types: InternalIP
EOF
}

resource "helm_release" "metrics-server" {
  name = "metrics-server"
  namespace = "kube-system"
  repository = "bitnami"
  chart = "metrics-server"
  version = var.helm_release["metrics-server"]
  values = [data.template_file.metrics-server-values.rendered]
}

data "template_file" "oauth-proxy-values" {
  template = <<EOF
app:
  useSSL: false
  provider: github
  clientID: "${var.dashboard_oauth_config["client_id"]}"
  clientSecret: "${var.dashboard_oauth_config["client_secret"]}"
  cookieSecret: "${var.dashboard_oauth_config["cookie_secret"]}"
  githubOrg: "${var.dashboard_oauth_config["github_org"]}"
  githubTeam: "${var.dashboard_oauth_config["github_team"]}"
  cookieSecure: true
  requestLogging: true
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
settings:
  clusterName: ${var.cluster_name}"
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
  paths:
  - /
  - /oauth2
  customPaths:
  - backend:
      serviceName: kubernetes-dashboard
      servicePort: 80
  - backend:
      serviceName: oauth2-proxy
      servicePort: 80
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
