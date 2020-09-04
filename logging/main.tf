resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

data "template_file" "fluentd" {
  template = <<EOF
elasticsearch:
  scheme: https
  sslVerify: false
  hosts: ${var.logging_config["es_host"]}
  auth:
    enabled: true
    user: ${var.logging_config["es_user"]}
    password: ${var.logging_config["es_pass"]}
  logstash:
    enabled: true
    prefix: "${var.cluster_name}-k8s"
  ilm:
    enabled: ${var.logging_config["es_ilm_enabled"]}
    policy_id: ${var.logging_config["es_ilm_policy"]}
prometheusRule:
  enabled: true
serviceMetric:
  enabled: true
serviceMonitor:
  enabled: true
EOF
}

resource "helm_release" "fluentd" {
  name = "fluentd-elasticsearch"
  namespace = "logging"
  repository = "kiwigrid"
  chart = "fluentd-elasticsearch"
  version = var.helm_release["fluentd-elasticsearch"]
  values = ["${data.template_file.fluentd.rendered}"]
  depends_on = [kubernetes_namespace.logging]
}
