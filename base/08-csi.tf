data "template_file" "aws-ebs-csi" {
  template = <<EOF
enableVolumeScheduling: true
enableVolumeResizing: true
enableVolumeSnapshot: true
EOF
}

resource "helm_release" "aws-ebs-csi" {
  name = "aws-ebs-csi-driver"
  namespace = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart = "aws-ebs-csi-driver"
  version = var.helm_release["aws-ebs-csi-driver"]
  values = [data.template_file.aws-ebs-csi.rendered]
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
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart = "aws-efs-csi-driver"
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
