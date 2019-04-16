resource "aws_iam_role_policy" "nginx-ingress" {
  name = "${var.cluster_id}-node-eip"
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

resource "helm_release" "nginx-ingress" {
  name = "nginx-ingress"
  namespace = "kube-system"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart = "nginx-ingress"
  version = "1.4.0"
  set {
    name = "controller.service.annotations"
    value = <<EOF
service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ${data.aws_acm_certificate.eks-acm.arn}
service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: ELBSecurityPolicy-TLS-1-2-2017-01
service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
EOF
  }
}
