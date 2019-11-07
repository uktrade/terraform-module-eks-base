locals {
  amazon-k8s-cni-release = "1.5"
  amazon-k8s-cni-version = "1.5.4"
  amazon-k8s-cni-url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v${local.amazon-k8s-cni-version}/config/v${local.amazon-k8s-cni-release}"
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

# data "template_file" "k8s-cni-patch" {
#   template = <<EOF
# spec:
#   template:
#     spec:
#       containers:
#         - name: aws-node
#           env:
#             - name: AWS_VPC_K8S_CNI_EXTERNALSNAT
#               value: "true"
# EOF
# }
#
# resource "null_resource" "k8s-cni-patch" {
#   provisioner "local-exec" {
#     command = <<EOF
# cat <<EOL | kubectl -n kube-system patch daemonset.apps aws-node -p '${data.template_file.k8s-cni-patch.rendered}'
# EOL
# EOF
#     environment {
#       KUBECONFIG = "${var.kubeconfig_filename}"
#     }
#   }
#   triggers {
#     build_number = "${sha1(data.http.k8s-cni.body)}"
#   }
#   depends_on = ["null_resource.k8s-cni"]
# }


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
