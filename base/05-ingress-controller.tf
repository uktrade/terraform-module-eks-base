resource "helm_release" "nginx-ingress" {
  name = "nginx-ingress"
  namespace = "kube-system"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart = "nginx-ingress"
  version = "1.4.0"
}
