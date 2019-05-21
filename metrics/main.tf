provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

locals {
  metrics_url = "https://raw.githubusercontent.com/aws-samples/aws-workshop-for-kubernetes/master/02-path-working-with-clusters/201-cluster-monitoring/templates/prometheus"
}

resource "null_resource" "prometheus-init" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "prometheus" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "grafana" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/grafana-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
