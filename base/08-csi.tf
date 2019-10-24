locals {
  aws-ebs-csi-driver-url = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/v${var.helm_release["aws-ebs-csi-driver"]}/helm-chart.tgz"
}

resource "helm_release" "aws-ebs-csi" {
  name = "aws-ebs-csi-driver"
  namespace = "kube-system"
  chart = "${local.aws-ebs-csi-driver-url}"
  set {
    name = "enableVolumeScheduling"
    value = "true"
  }
  set {
    name = "enableVolumeResizing"
    value = "true"
  }
  set {
    name = "enableVolumeSnapshot"
    value = "true"
  }
}
