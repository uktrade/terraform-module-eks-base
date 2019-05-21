provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

locals {
  metrics_url = "https://raw.githubusercontent.com/aws-samples/aws-workshop-for-kubernetes/master/02-path-working-with-clusters/201-cluster-monitoring/templates/prometheus"
}

data "http" "prometheus-init" {
  url = "${local.metrics_url}/prometheus-bundle.yaml"
}

resource "null_resource" "prometheus-init" {
  provisioner "local-exec" {
    command = "kubectl apply ${data.prometheus-init.body}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "http" "prometheus" {
  url = "${local.metrics_url}/prometheus.yaml"
}

resource "null_resource" "prometheus-init" {
  provisioner "local-exec" {
    command = "kubectl apply ${data.prometheus.body}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "http" "grafana" {
  url = "${local.metrics_url}/grafana-bundle.yaml"
}

resource "null_resource" "grafana" {
  provisioner "local-exec" {
    command = "kubectl apply ${data.grafana.body}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
