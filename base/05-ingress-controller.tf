resource "aws_iam_role_policy" "nginx-ingress" {
  name = "${var.cluster_id}-node-ingress"
  role = "${var.worker_iam_role_name}"
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
  domain = "${var.cluster_domain}"
  statuses = ["ISSUED"]
}

# data "template_file" "nginx-tcp" {
#   template = <<EOF
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   labels:
#     app.kubernetes.io/name: nginx-ingress-controller
#     app.kubernetes.io/part-of: nginx-ingress-controller
#   name: tcp-services
# EOF
# }
#
# data "template_file" "nginx-udp" {
#   template = <<EOF
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   labels:
#     app.kubernetes.io/name: nginx-ingress-controller
#     app.kubernetes.io/part-of: nginx-ingress-controller
#   name: udp-services
# EOF
# }
#
# resource "null_resource" "nginx-tcp" {
#   provisioner "local-exec" {
#     command = <<EOF
# cat <<EOL | kubectl -n kube-system apply -f -
# ${data.template_file.nginx-tcp.rendered}
# EOL
# EOF
#     environment {
#       KUBECONFIG = "${var.kubeconfig_filename}"
#     }
#   }
# }
#
# resource "null_resource" "nginx-udp" {
#   provisioner "local-exec" {
#     command = <<EOF
# cat <<EOL | kubectl -n kube-system apply -f -
# ${data.template_file.nginx-udp.rendered}
# EOL
# EOF
#     environment {
#       KUBECONFIG = "${var.kubeconfig_filename}"
#     }
#   }
# }

data "template_file" "nginx-ingress-values" {
  template = <<EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
      service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ${data.aws_acm_certificate.eks-acm.arn}
      service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: ELBSecurityPolicy-TLS-1-2-2017-01
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
  config:
    server-tokens: "false"
    use-forwarded-headers: "true"
    use-proxy-protocol: "false"
    enable-vts-status: "true"
    proxy-real-ip-cidr: 0.0.0.0/0
    proxy-body-size: 5G
  extraArgs:
    annotations-prefix: nginx.ingress.kubernetes.io
  publishService:
    enabled: true
defaultBackend:
  enabled: false
stats:
  enabled: true
metrics:
  enabled: true
tcp: {}
udp: {}
EOF
}

resource "helm_release" "nginx-ingress" {
  name = "nginx-ingress"
  namespace = "kube-system"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart = "nginx-ingress"
  version = "1.6.0"
  values = ["${data.template_file.nginx-ingress-values.rendered}"]
}
