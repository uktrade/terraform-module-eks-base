#
# Autoscaler helm chart
#

data "template_file" "autoscaler" {
  template = <<EOF
cloudProvider: aws
awsRegion: ${data.aws_region.current.name}
autoDiscovery:
  clusterName: ${var.cluster_id}
podAnnotations:
  cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
extraArgs:
  balance-similar-node-groups: true
  skip-nodes-with-system-pods: false
rbac:
  create: true
serviceMonitor:
  enabled: true
EOF
}

resource "helm_release" "autoscaler" {
  name = "cluster-autoscaler"
  namespace = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart = "cluster-autoscaler"
  version = var.helm_release["cluster-autoscaler"]
  values = [data.template_file.autoscaler.rendered]
}
