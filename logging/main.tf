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
configMaps:
  output.conf: |
    <match **>
      ssl_verify false
      user ${var.logging_config["es_user"]}
      password ${var.logging_config["es_pass"]}
    </match>
EOF
}

resource "helm_release" "fluentd" {
  name = "fluentd-elasticsearch"
  namespace = "logging"
  repository = "stable"
  chart = "fluentd-elasticsearch"
  version = var.helm_release["fluentd-elasticsearch"]
  values = ["${data.template_file.fluentd.rendered}"]
  depends_on = [kubernetes_namespace.logging]
}
