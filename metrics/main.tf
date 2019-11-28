provider "kubernetes" {
  config_path = var.kubeconfig_filename
}

data "template_file" "prometheus-values" {
  template = <<EOF
prometheusOperator:
  nodeSelector:
    role: worker
prometheus:
  prometheusSpec:
    enableAdminAPI: true
    nodeSelector:
      role: worker
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/configuration-snippet: |
        rewrite ^/$ /targets last;
    hosts:
      - "status.${var.cluster_domain}"
alertmanager:
  alertmanagerSpec:
    nodeSelector:
      role: worker
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    hosts:
      - "alert.${var.cluster_domain}"
grafana:
  env:
    GF_SERVER_DOMAIN: "metric.${var.cluster_domain}"
    GF_SERVER_ROOT_URL: "https://metric.${var.cluster_domain}/"
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
      - "metric.${var.cluster_domain}"
  nodeSelector:
    role: worker
EOF
}

resource "helm_release" "prometheus" {
  name = "prometheus"
  namespace = "monitoring"
  repository = "stable"
  chart = "prometheus-operator"
  version = var.helm_release["prometheus-operator"]
  values = ["${data.template_file.prometheus-values.rendered}"]
}
