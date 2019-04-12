locals {
  amazon-k8s-cni-release = "1.3"
  amazon-k8s-cni-url = "https://github.com/aws/amazon-vpc-cni-k8s/tree/master/config/v${local.amazon-k8s-cni-release}"
}

resource "null_resource" "k8s-cni" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/aws-k8s-cni.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "k8s-calico" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/calico.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
