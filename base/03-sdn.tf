locals {
  amazon-k8s-cni-release = "1.4"
  amazon-k8s-cni-url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/v${local.amazon-k8s-cni-release}"
}

data "http" "k8s-cni" {
  url = "${local.amazon-k8s-cni-url}/aws-k8s-cni.yaml"
}

resource "null_resource" "k8s-cni" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/aws-k8s-cni.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.k8s-cni.body)}"
  }
}

data "http" "k8s-calico" {
  url = "${local.amazon-k8s-cni-url}/calico.yaml"
}

resource "null_resource" "k8s-calico" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/calico.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.k8s-calico.body)}"
  }
}

data "http" "k8s-calico-metrics" {
  url = "${local.amazon-k8s-cni-url}/cni-metrics-helper.yaml"
}

resource "null_resource" "k8s-calico-metrics" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.amazon-k8s-cni-url}/cni-metrics-helper.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.k8s-calico-metrics.body)}"
  }
}
