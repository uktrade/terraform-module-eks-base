resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

data "template_file" "fluentd" {
  template = <<EOF
elasticsearch:
  scheme: https
  host: ${var.logging_config["es_host"]}
  port: ${var.logging_config["es_port"]}
  logstash_prefix: "${var.cluster_name}-k8s"
env:
  OUTPUT_USER: ${var.logging_config["es_user"]}
  ELASTICSEARCH_PASSWORD: ${var.logging_config["es_pass"]}
EOF
}

resource "helm_release" "fluentd" {
  name = "fluentd-elasticsearch"
  namespace = "logging"
  repository = "stable"
  chart = "fluentd-elasticsearch"
  version = var.helm_release["fluentd-elasticsearch"]
  values = ["${data.template_file.fluentd.rendered}", "${file("${path.module}/fluentd.conf")}"]
  depends_on = [kubernetes_namespace.logging]
}
