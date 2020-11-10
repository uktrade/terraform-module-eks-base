resource "helm_release" "aws-calico" {
  name = "aws-calico"
  namespace = "kube-system"
  repository = "eks"
  chart = "aws-calico"
  version = var.helm_release["aws-calico"]
}
