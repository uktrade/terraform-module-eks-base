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
EOF
}

resource "helm_release" "fluentd" {
  name = "fluentd-cloudwatch"
  namespace = "logging"
  repository = "incubator"
  chart = "fluentd-cloudwatch"
  version = "0.9.1"
  values = ["${data.template_file.fluentd.rendered}"]
}
