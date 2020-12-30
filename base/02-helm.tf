resource "helm_release" "reloader" {
  name = "reloader"
  namespace = "kube-system"
  repository = "https://stakater.github.io/stakater-charts"
  chart = "reloader"
  version = var.helm_release["reloader"]
}
