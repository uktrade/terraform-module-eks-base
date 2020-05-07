provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_filename
  }
}

resource "null_resource" "helm_update" {
  provisioner "local-exec" {
    command = <<EOT
helm repo add stable https://kubernetes-charts.storage.googleapis.com &&
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com &&
helm repo add bitnami https://charts.bitnami.com/bitnami &&
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
