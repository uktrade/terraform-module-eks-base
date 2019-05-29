data "template_file" "autoscaler" {
  template = <<EOF
cloudProvider: aws
awsRegion: ${data.aws_region.current.name}
autoDiscovery:
  clusterName: ${var.cluster_id}
rbac:
  create: true
serviceMonitor:
  enabled: true
EOF
}

resource "helm_release" "autoscaler" {
  name = "cluster-autoscaler"
  namespace = "kube-system"
  repository = "stable"
  chart = "cluster-autoscaler"
  version = "0.13.2"
  values = ["${data.template_file.autoscaler.rendered}"]
}
