resource "helm_release" "nginx-ingress" {
  name = "nginx-ingress"
  repository = "{data.helm_repository.stable.metadata.0.name}"
  chart = "nginx-ingress"
  version = "1.4.0"
}
