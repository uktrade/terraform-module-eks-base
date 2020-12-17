provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_filename
  }
}

resource "null_resource" "helm_update" {
  provisioner "local-exec" {
    command = <<EOT
helm repo add stable https://charts.helm.sh/stable || true &&
helm repo add incubator https://charts.helm.sh/incubator || true &&
helm repo add eks https://aws.github.io/eks-charts || true &&
helm repo add bitnami https://charts.bitnami.com/bitnami || true &&
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard || true &&
helm repo add kiwigrid https://kiwigrid.github.io || true &&
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true &&
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true &&
helm repo add cloudposse https://charts.cloudposse.com/incubator || true &&
helm repo add twuni https://helm.twun.io || true &&
helm repo add stakater https://stakater.github.io/stakater-charts || true &&
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

resource "helm_release" "reloader" {
  name = "reloader"
  namespace = "kube-system"
  repository = "stakater"
  chart = "reloader"
  version = var.helm_release["reloader"]
}
