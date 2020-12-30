resource "helm_release" "aws-calico" {
  name = "aws-calico"
  namespace = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-calico"
  version = var.helm_release["aws-calico"]
}
