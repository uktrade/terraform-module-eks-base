provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

data "template_file" "prometheus-values" {
  template = <<EOF
prometheusOperator:
  nodeSelector:
    role: worker
prometheus:
  prometheusSpec:
    nodeSelector:
      role: worker
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
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
    hosts:
      - "alert.${var.cluster_domain}"
grafana:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
      - "metric.${var.cluster_domain}"
EOF
}

resource "helm_release" "prometheus" {
  name = "prometheus"
  namespace = "monitoring"
  repository = "stable"
  chart = "prometheus-operator"
  values = ["${data.template_file.prometheus-values.rendered}"]
}

data "template_file" "grafana-oauth" {
  template = <<EOF
spec:
  template:
    spec:
      nodeSelector:
        role: worker
      containers:
        - name: grafana
          env:
            - name: GF_SERVER_DOMAIN
              value: "metric.${var.cluster_domain}"
            - name: GF_SERVER_ROOT_URL
              value: "https://metric.${var.cluster_domain}/"
            - name: GF_AUTH_GITHUB_ENABLED
              value: "true"
            - name: GF_AUTH_GITHUB_ALLOW_SIGN_UP
              value: "true"
            - name: GF_AUTH_GITHUB_CLIENT_ID
              value: "${var.metric_config["oauth_client_id"]}"
            - name: GF_AUTH_GITHUB_CLIENT_SECRET
              value: "${var.metric_config["oauth_client_secret"]}"
            - name: GF_AUTH_GITHUB_ALLOWED_ORGANIZATIONS
              value: "${var.metric_config["oauth_organization"]}"
            - name: GF_AUTH_GITHUB_TEAM_IDS
              value: "${var.metric_config["oauth_team"]}"
EOF
}

resource "null_resource" "grafana-oauth" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n monitoring patch deployment prometheus-grafana -p '${data.template_file.grafana-oauth.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    helm = "${helm_release.prometheus.version}"
    patch = "${sha1(data.template_file.grafana-oauth.rendered)}"
  }
  depends_on = ["helm_release.prometheus"]
}
