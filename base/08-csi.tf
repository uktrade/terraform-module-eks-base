locals {
  aws-ebs-csi-driver-url = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/v${var.helm_release["aws-ebs-csi-driver"]}/helm-chart.tgz"
  aws-efs-csi-driver-url = "https://github.com/kubernetes-sigs/aws-efs-csi-driver/releases/download/v${var.helm_release["aws-efs-csi-driver"]}/helm-chart.tgz"
}

resource "helm_release" "aws-ebs-csi" {
  name = "aws-ebs-csi-driver"
  namespace = "kube-system"
  chart = local.aws-ebs-csi-driver-url
  version = var.helm_release["aws-ebs-csi-driver"]
}

resource "kubernetes_storage_class" "aws-ebs-storage-class" {
  metadata {
    name = "ebs"
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    encrypted = "true"
  }
}

resource "helm_release" "aws-efs-csi" {
  name = "aws-efs-csi-driver"
  namespace = "kube-system"
  chart = local.aws-efs-csi-driver-url
  version = var.helm_release["aws-efs-csi-driver"]
}

resource "kubernetes_storage_class" "aws-efs-storage-class" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    encrypted = "true"
  }
}
