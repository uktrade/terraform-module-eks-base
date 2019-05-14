resource "helm_release" "heapster" {
  name = "heapster"
  namespace = "kube-system"
  repository = "stable"
  chart = "heapster"
  version = "0.3.3"
}

data "template_file" "oauth-proxy-values" {
  template = <<EOF
config:
  configFile: |-
    provider = "${var.dashboard_oauth_config["provider"]}"
    client-id = "${var.dashboard_oauth_config["client_id"]}"
    client-secret = "${var.dashboard_oauth_config["client_secret"]}"
    cookie-secret = "${var.dashboard_oauth_config["cookie_secret"]}"
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

data "template_file" "dashboard-values" {
  template = <<EOF
enableInsecureLogin: true
service:
  externalPort: 8080
  internalPort: 8080
ingress:
  enabled: true
  hosts:
    - "console.${var.cluster_domain}"
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
EOF
}

resource "helm_release" "dashboard" {
  name = "kubernetes-dashboard"
  namespace = "kube-system"
  repository = "stable"
  chart = "kubernetes-dashboard"
  version = "1.5.1"
  values = ["${data.template_file.dashboard-values.rendered}"]
}

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