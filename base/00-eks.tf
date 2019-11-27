locals {
  eks = {
    "1.12" = {
      cni = "1.5.3"
      dns = "1.2.2"
      kube-proxy = "1.12.10"
    },
    "1.13" = {
      cni = "1.5.3"
      dns = "1.2.6"
      kube-proxy = "1.13.10"
    },
    "1.14" = {
      cni = "1.5.5"
      dns = "1.3.1"
      kube-proxy = "1.14.7"
    }
  }
}

resource "null_resource" "k8s-cni" {
  provisioner "local-exec" {
    command = "kubectl -n kube-system set image daemonset.apps/aws-node aws-node=$(kubectl -n kube-system get daemonset.apps/aws-node -o json | jq -rc '.spec.template.spec.containers[].image' | sed -E 's/v([0-9\\.]+)$/v${local.eks[var.eks_config["version"]]["cni"]}/')"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    eks_version = var.eks_config["version"]
    build_number = local.eks[var.eks_config["version"]]["cni"]
  }
}

resource "null_resource" "k8s-dns" {
  provisioner "local-exec" {
    command = "kubectl -n kube-system set image deployment.apps/coredns coredns=$(kubectl -n kube-system get deployment.apps/coredns -o json | jq -rc '.spec.template.spec.containers[].image' | sed -E 's/v([0-9\\.]+)$/v${local.eks[var.eks_config["version"]]["dns"]}/')"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    eks_version = var.eks_config["version"]
    build_number = local.eks[var.eks_config["version"]]["dns"]
  }
}

resource "null_resource" "k8s-proxy" {
  provisioner "local-exec" {
    command = "kubectl -n kube-system set image daemonset.apps/kube-proxy kube-proxy=$(kubectl -n kube-system get daemonset.apps/kube-proxy -o json | jq -rc '.spec.template.spec.containers[].image' | sed -E 's/v([0-9\\.]+)$/v${local.eks[var.eks_config["version"]]["kube-proxy"]}/')"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    eks_version = var.eks_config["version"]
    build_number = local.eks[var.eks_config["version"]]["kube-proxy"]
  }
}
