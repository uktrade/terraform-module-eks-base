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
