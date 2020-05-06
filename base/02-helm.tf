provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_filename
  }
}

data "helm_repository" "stable" {
    name = "stable"
    url = "https://kubernetes-charts.storage.googleapis.com"
}

data "helm_repository" "incubator" {
    name = "incubator"
    url = "https://kubernetes-charts-incubator.storage.googleapis.com"
}

data "helm_repository" "bitnami" {
    name = "bitnami"
    url = "https://charts.bitnami.com/bitnami"
}

resource "null_resource" "helm_update" {
  provisioner "local-exec" {
    command = "helm repo update"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = timestamp()
  }
}
