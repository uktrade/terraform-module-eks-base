provider "helm" {
  alias = "helm"
  install_tiller = true
  namespace = "kube-system"
  service_account = "tiller"
  kubernetes {
    config_path = "${var.kubeconfig_filename}"
  }
}
