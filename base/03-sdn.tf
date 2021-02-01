#
# Install and setup k8s SDN
# TODO: namespace segregated SDN config
#

resource "helm_release" "aws-calico" {
  name = "aws-calico"
  namespace = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-calico"
  version = var.helm_release["aws-calico"]
}
