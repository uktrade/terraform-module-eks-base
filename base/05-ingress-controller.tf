resource "aws_iam_role_policy" "nginx-ingress" {
  name = "${var.cluster_id}-node-ingress"
  role = var.worker_iam_role_name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:AttachLoadBalancers",
      "autoscaling:DetachLoadBalancers",
      "autoscaling:DetachLoadBalancerTargetGroups",
      "autoscaling:AttachLoadBalancerTargetGroups",
      "autoscaling:DescribeLoadBalancerTargetGroups",
      "elasticloadbalancing:*",
      "ec2:Describe*",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates"
    ],
    "Resource": [
      "*"
    ]
  }]
}
EOF
}

data "aws_acm_certificate" "eks-acm" {
  domain = "${var.eks_extra_config["domain"]}"
  statuses = ["ISSUED"]
  types = ["AMAZON_ISSUED"]
  most_recent = true
}

locals {
  acm_certificate_arn = coalesce(lookup(var.eks_extra_config, "acm_certificate_arn", ""), data.aws_acm_certificate.eks-acm.arn)
}

resource "kubernetes_config_map" "tcp-services" {
  metadata {
    name = "tcp-services"
    namespace = "kube-system"
  }
}

resource "kubernetes_config_map" "udp-services" {
  metadata {
    name = "udp-services"
    namespace = "kube-system"
  }
}

data "template_file" "nginx-ingress-values" {
  template = <<EOF
controller:
  service:
    targetPorts:
      https: 80
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
      service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ${local.acm_certificate_arn}
      service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: ELBSecurityPolicy-TLS-1-2-2017-01
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
  config:
    server-tokens: "false"
    ssl-redirect: "true"
    use-forwarded-headers: "true"
    use-proxy-protocol: "false"
    enable-vts-status: "true"
    proxy-real-ip-cidr: 0.0.0.0/0
    proxy-body-size: 5G
  extraArgs:
    tcp-services-configmap: $(POD_NAMESPACE)/tcp-services
    udp-services-configmap: $(POD_NAMESPACE)/udp-services
    annotations-prefix: nginx.ingress.kubernetes.io
  publishService:
    enabled: true
  replicaCount: ${length(data.aws_availability_zones.current.names)}
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: failure-domain.beta.kubernetes.io/zone
        labelSelector:
          matchLabels:
            # release: nginx-ingress
            role: worker
defaultBackend:
  enabled: false
stats:
  enabled: true
metrics:
  enabled: true
EOF
}

resource "helm_release" "nginx-ingress" {
  name = "nginx-ingress"
  namespace = "kube-system"
  repository = "stable"
  chart = "nginx-ingress"
  version = var.helm_release["nginx-ingress"]
  values = ["${data.template_file.nginx-ingress-values.rendered}"]
  # wait = false
  depends_on = [kubernetes_config_map.tcp-services, kubernetes_config_map.udp-services]
}

data "template_file" "nginx-ingress-external-values" {
  template = <<EOF
controller:
  service:
    targetPorts:
      https: 80
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ${local.acm_certificate_arn}
      service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: ELBSecurityPolicy-TLS-1-2-2017-01
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
  config:
    server-tokens: "false"
    ssl-redirect: "true"
    use-forwarded-headers: "true"
    use-proxy-protocol: "false"
    enable-vts-status: "true"
    proxy-real-ip-cidr: 0.0.0.0/0
    proxy-body-size: 5G
  ingressClass: nginx-external
  extraArgs:
    tcp-services-configmap: $(POD_NAMESPACE)/tcp-services
    udp-services-configmap: $(POD_NAMESPACE)/udp-services
    annotations-prefix: nginx.ingress.kubernetes.io
  publishService:
    enabled: true
  replicaCount: ${length(data.aws_availability_zones.current.names)}
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: failure-domain.beta.kubernetes.io/zone
        labelSelector:
          matchLabels:
            role: worker
defaultBackend:
  enabled: false
stats:
  enabled: true
metrics:
  enabled: true
EOF
}

resource "helm_release" "nginx-ingress-external" {
  name = "nginx-ingress-external"
  namespace = "kube-system"
  repository = "stable"
  chart = "nginx-ingress"
  version = var.helm_release["nginx-ingress"]
  values = ["${data.template_file.nginx-ingress-external-values.rendered}"]
  # wait = false
  depends_on = [kubernetes_config_map.tcp-services, kubernetes_config_map.udp-services]
}
