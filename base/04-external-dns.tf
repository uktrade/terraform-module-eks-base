data "aws_route53_zone" "k8s-dns" {
  name = var.eks_extra_config["domain"]
}

resource "aws_iam_role_policy" "eks-route53" {
  name = "${var.cluster_id}-route53"
  role = var.worker_iam_role_name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/${data.aws_route53_zone.k8s-dns.zone_id}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

data "template_file" "external-dns-values" {
  template = <<EOF
provider: aws
aws:
  zoneType: public
domainFilters:
  - ${var.eks_extra_config["domain"]}
zoneIdFilters:
  - ${data.aws_route53_zone.k8s-dns.zone_id}
txtOwnerId: ${var.cluster_id}
sources:
  - service
  - ingress
policy: sync
rbac:
  create: true
nodeSelector:
  role: worker
EOF
}

resource "helm_release" "external-dns" {
  name = "external-dns"
  namespace = "kube-system"
  repository = "bitnami"
  chart = "external-dns"
  version = var.helm_release["external-dns"]
  values = [data.template_file.external-dns-values.rendered]
  depends_on = [aws_iam_role_policy.eks-route53]
}
