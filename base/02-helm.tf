provider "helm" {
  alias = "helm"
  install_tiller = true
  namespace = "kube-system"
  service_account = "tiller"
  kubernetes {
    config_path = "${var.kubeconfig_filename}"
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
