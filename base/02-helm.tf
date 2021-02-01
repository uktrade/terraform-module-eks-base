#
# Extra helm charts required to function.
#
# Current helm chart repo being used:
# NAME                	URL
# stable              	https://charts.helm.sh/stable
# incubator           	https://charts.helm.sh/incubator
# eks                 	https://aws.github.io/eks-charts
# bitnami             	https://charts.bitnami.com/bitnami
# kubernetes-dashboard	https://kubernetes.github.io/dashboard
# kiwigrid            	https://kiwigrid.github.io
# prometheus-community	https://prometheus-community.github.io/helm-charts
# ingress-nginx       	https://kubernetes.github.io/ingress-nginx
# stakater            	https://stakater.github.io/stakater-charts
# aws-ebs-csi-driver  	https://kubernetes-sigs.github.io/aws-ebs-csi-driver
# aws-efs-csi-driver  	https://kubernetes-sigs.github.io/aws-efs-csi-driver
# harbor              	https://helm.goharbor.io
# sentry              	https://sentry-kubernetes.github.io/charts

resource "helm_release" "reloader" {
  name = "reloader"
  namespace = "kube-system"
  repository = "https://stakater.github.io/stakater-charts"
  chart = "reloader"
  version = var.helm_release["reloader"]
}
