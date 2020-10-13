data "template_file" "prometheus-values" {
  template = <<EOF
prometheus:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/configuration-snippet: |
        rewrite ^/$ /targets last;
    hosts:
      - "status.${var.eks_extra_config["domain"]}"
alertmanager:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    hosts:
      - "alert.${var.eks_extra_config["domain"]}"
grafana:
  persistence:
    enabled: true
  env:
    GF_SERVER_DOMAIN: "metric.${var.eks_extra_config["domain"]}"
    GF_SERVER_ROOT_URL: "https://metric.${var.eks_extra_config["domain"]}/"
    GF_AUTH_GITHUB_ENABLED: "true"
    GF_AUTH_GITHUB_ALLOW_SIGN_UP: "true"
    GF_AUTH_GITHUB_CLIENT_ID: "${var.metric_config["oauth_client_id"]}"
    GF_AUTH_GITHUB_CLIENT_SECRET: "${var.metric_config["oauth_client_secret"]}"
    GF_AUTH_GITHUB_ALLOWED_ORGANIZATIONS: "${var.metric_config["oauth_organization"]}"
    GF_AUTH_GITHUB_TEAM_IDS: "${var.metric_config["oauth_team"]}"
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    hosts:
      - "metric.${var.eks_extra_config["domain"]}"
kubeEtcd:
  enabled: false
EOF
}

resource "helm_release" "prometheus" {
  name = "prometheus"
  namespace = "monitoring"
  repository = "prometheus-community"
  chart = "kube-prometheus-stack"
  version = var.helm_release["kube-prometheus-stack"]
  values = [data.template_file.prometheus-values.rendered]
}
