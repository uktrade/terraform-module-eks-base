provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }
  subject {
    kind = "ServiceAccount"
    name = "tiller"
    namespace = "kube-system"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  depends_on = ["kubernetes_service_account.tiller"]
}

resource "null_resource" "helm_init" {
  provisioner "local-exec" {
    command = "helm init --service-account tiller --upgrade --wait"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  depends_on = ["kubernetes_cluster_role_binding.tiller"]
}

provider "helm" {
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
