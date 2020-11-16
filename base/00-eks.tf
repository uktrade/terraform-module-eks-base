locals {
  eks_version = {
    "1.14" = {
      cni = "1.7.5"
      dns = "1.6.6"
      kube-proxy = "1.14.9"
    }
    "1.15" = {
      cni = "1.7.5"
      dns = "1.6.6"
      kube-proxy = "1.15.12"
    }
    "1.16" = {
      cni = "1.7.5"
      dns = "1.6.6"
      kube-proxy = "1.16.15"
    }
    "1.17" = {
      cni = "1.7.5"
      dns = "1.6.6"
      kube-proxy = "1.17.12-eksbuild.1"
    }
    "1.18" = {
      cni = "1.7.5"
      dns = "1.7.0-eksbuild.1"
      kube-proxy = "1.18.9-eksbuild.1"
    }
  }
  eks = merge(local.eks_version[var.eks_config["version"]], lookup(var.eks_config, "components", {}))
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

data "template_file" "aws-cni" {
template = <<EOF
init:
  image:
    tag: v${local.eks["cni"]}
    region: ${data.aws_region.current.name}
EOF
}

resource "helm_release" "aws-cni" {
  name = "aws-vpc-cni"
  namespace = "kube-system"
  repository = "eks"
  chart = "aws-vpc-cni"
  version = var.helm_release["aws-vpc-cni"]
  values = [data.template_file.aws-cni.rendered]
}

data "template_file" "aws-node-termination-handler" {
template = <<EOF
enablePrometheusServer: true
enableScheduledEventDraining: true
enableSpotInterruptionDraining: true
enableRebalanceMonitoring: false
useHostNetwork: true
EOF
}

resource "helm_release" "aws-node-termination-handler" {
  name = "aws-node-termination-handler"
  namespace = "kube-system"
  repository = "eks"
  chart = "aws-node-termination-handler"
  version = var.helm_release["aws-node-termination-handler"]
  values = [data.template_file.aws-node-termination-handler.rendered]
}
