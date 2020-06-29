locals {
  eks_version = {
    "1.13" = {
      cni = "1.6.3"
      dns = "1.6.6"
      kube-proxy = "1.13.12"
    },
    "1.14" = {
      cni = "1.6.3"
      dns = "1.6.6"
      kube-proxy = "1.14.9"
    }
    "1.15" = {
      cni = "1.6.3"
      dns = "1.6.6"
      kube-proxy = "1.15.11"
    }
    "1.16" = {
      cni = "1.6.3"
      dns = "1.6.6"
      kube-proxy = "1.16.8"
    }
  }
  eks = merge(local.eks_version[var.eks_config["version"]], lookup(var.eks_config, "components", {}))
}

resource "null_resource" "k8s-cni" {
  provisioner "local-exec" {
    command = "kubectl -n kube-system set image daemonset.apps/aws-node aws-node=$(kubectl -n kube-system get daemonset.apps/aws-node -o json | jq -rc '.spec.template.spec.containers[].image' | sed -E 's/v([0-9\\.]+)$/v${local.eks["cni"]}/')"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    eks_version = var.eks_config["version"]
    build_number = local.eks["cni"]
  }
}

resource "null_resource" "k8s-dns" {
  provisioner "local-exec" {
    command = "kubectl -n kube-system set image deployment.apps/coredns coredns=$(kubectl -n kube-system get deployment.apps/coredns -o json | jq -rc '.spec.template.spec.containers[].image' | sed -E 's/v([0-9\\.]+)$/v${local.eks["dns"]}/')"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    eks_version = var.eks_config["version"]
    build_number = local.eks["dns"]
  }
}

resource "null_resource" "k8s-proxy" {
  provisioner "local-exec" {
    command = "kubectl -n kube-system set image daemonset.apps/kube-proxy kube-proxy=$(kubectl -n kube-system get daemonset.apps/kube-proxy -o json | jq -rc '.spec.template.spec.containers[].image' | sed -E 's/v([0-9\\.]+)$/v${local.eks["kube-proxy"]}/')"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    eks_version = var.eks_config["version"]
    build_number = local.eks["kube-proxy"]
  }
}
