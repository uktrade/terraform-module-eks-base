data "template_file" "autoscaler" {
  template = <<EOF
cloudProvider: aws
awsRegion: ${data.aws_region.current.name}
autoDiscovery:
  clusterName: ${var.cluster_id}
podAnnotations:
  cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
extraArgs:
  v: 4
  stderrthreshold: info
  logtostderr: true
  balance-similar-node-groups: true
  skip-nodes-with-system-pods: false
sslCertHostPath: /etc/ssl/certs/ca-bundle.crt
rbac:
  create: true
serviceMonitor:
  enabled: true
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "autoscaler" {
  name = "cluster-autoscaler"
  namespace = "kube-system"
  repository = "stable"
  chart = "cluster-autoscaler"
  version = var.helm_release["cluster-autoscaler"]
  values = ["${data.template_file.autoscaler.rendered}"]
}
