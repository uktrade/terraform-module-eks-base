resource "helm_release" "heapster" {
  name = "heapster"
  namespace = "kube-system"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart = "heapster"
  version = "0.3.3"
}

data "template_file" "oauth-proxy-values" {
  template = <<EOF
config:
  configFile: |-
    provider = "${var.dashboard_oauth_config["provider"]}"
    client_id = "${var.dashboard_oauth_config["client_id"]}"
    client_secret = "${var.dashboard_oauth_config["client_secret"]}"
    github_org = "${var.dashboard_oauth_config["github_org"]}"
    github_team = "${var.dashboard_oauth_config["github_team"]}"
    email_domains = ["*"]
EOF
}

resource "helm_release" "oauth-proxy" {
  name = "oauth2-proxy"
  namespace = "kube-system"
  repository = "stable"
  chart = "oauth2-proxy"
  version = "0.12.1"
  values = ["${data.template_file.oauth-proxy-values.rendered}"]
}

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart = "kubernetes-dashboard"
  version = "1.5.1"
}

data "template_file" "dashboard-oauth-ingress" {
  template = <<EOF
kind: Ingress
metadata:
  name: dashboard-oauth2
  namespace: kube-system
spec:
  rules:
  - host: console.v3.uktrade.io
    http:
      paths:
      - path: /oauth2
        backend:
          serviceName: oauth2-proxy
          servicePort: 4180
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 8080
EOF
}
