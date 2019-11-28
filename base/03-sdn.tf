locals {
  amazon-k8s-cni-release = regex("[0-9]{1,2}\\.[0-9]{1,2}", local.eks["cni"])
  amazon-k8s-cni-url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v${local.eks["cni"]}/config/v${local.amazon-k8s-cni-release}"
}

data "http" "k8s-calico" {
  url = "${local.amazon-k8s-cni-url}/calico.yaml"
}

resource "null_resource" "k8s-calico" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/calico.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.http.k8s-calico.body)
    release = local.amazon-k8s-cni-release
  }
  depends_on = [null_resource.k8s-cni]
}

data "http" "k8s-calico-metrics" {
  url = "${local.amazon-k8s-cni-url}/cni-metrics-helper.yaml"
}

resource "null_resource" "k8s-calico-metrics" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/cni-metrics-helper.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.http.k8s-calico-metrics.body)
    release = local.amazon-k8s-cni-release
  }
  depends_on = [null_resource.k8s-calico]
}
