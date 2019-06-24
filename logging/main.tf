provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

data "template_file" "fluentd" {
  template = <<EOF
awsRegion: ${var.logging_config["aws_region"]}
awsAccessKeyId: ${var.logging_config["aws_access_key"]}
awsSecretAccessKey: ${var.logging_config["aws_secret_key"]}
logGroupName: ${var.logging_config["aws_log_group"]}
rbac:
  create: true
image:
  tag: v1.4.2-debian-cloudwatch-1.0
extraVars:
  - name: CLUSTER_NAME
    value: "${var.cluster_id}"
EOF
}

resource "helm_release" "fluentd" {
  name = "fluentd-cloudwatch"
  namespace = "logging"
  repository = "incubator"
  chart = "fluentd-cloudwatch"
  values = ["${data.template_file.fluentd.rendered}", "${file("${path.module}/fluentd.conf")}"]
}
