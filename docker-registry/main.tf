resource "kubernetes_namespace" "tools" {
  metadata {
    name = "tools"
  }
}

data "template_file" "harbor-values" {
  template = <<EOF
expose:
  type: ingress
  tls:
    enabled: false
  ingress:
    hosts:
      core: registry.${var.eks_extra_config["domain"]}
      notary: harbor-notary.${var.eks_extra_config["domain"]}
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
internalTLS:
  enabled: false
persistence:
  enabled: true
  imageChartStorage:
    s3:
      region: ${var.registry_config["s3_region"]}
      bucket: ${var.registry_config["s3_bucket"]}
      accessKey: ${var.registry_config["s3_accesskey"]}
      secretKey: ${var.registry_config["s3_secretkey"]}
      encrypt: true
      secure: true
externalURL: https://registry.${var.eks_extra_config["domain"]}
chartmuseum:
  enabled: true
clair:
  enabled: false
trivy:
  enabled: true
notary:
  enabled: true
database:
  type: external
  external:
    host: ${var.registry_config["db_host"]}
    port: ${var.registry_config["db_port"]}
    username: ${var.registry_config["db_user"]}
    password: ${var.registry_config["db_password"]}
    sslmode: require
EOF
}

resource "helm_release" "harbor" {
  name = "harbor"
  namespace = "tools"
  repository = "https://helm.goharbor.io"
  chart = "harbor"
  version = var.helm_release["harbor"]
  values = [data.template_file.harbor-values.rendered]
}
