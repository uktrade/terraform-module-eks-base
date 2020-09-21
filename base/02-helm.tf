provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_filename
  }
}

resource "null_resource" "helm_update" {
  provisioner "local-exec" {
    command = <<EOT
helm repo add stable https://kubernetes-charts.storage.googleapis.com || true &&
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com || true &&
helm repo add bitnami https://charts.bitnami.com/bitnami || true &&
helm repo add funkypenguin-kubernetes-dashboard https://funkypenguin.github.io/helm-kubernetes-dashboard || true &&
helm repo add kiwigrid https://kiwigrid.github.io || true &&
helm repo update
EOT
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = timestamp()
  }
}
