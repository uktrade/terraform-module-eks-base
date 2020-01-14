locals {
  iam_authenticator = "https://raw.githubusercontent.com/kubernetes-sigs/aws-iam-authenticator/master/deploy/iamidentitymapping.yaml"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "eks-admin" {
  name = "eks-admin"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks-admin" {
  role = aws_iam_role.eks-admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "http" "eks-admin-crd" {
  url = local.iam_authenticator
}

resource "null_resource" "eks-admin-crd" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.iam_authenticator}"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.http.eks-admin-crd.body)
  }
  depends_on = [aws_iam_role.eks-admin]
}

data "template_file" "eks-admin" {
  template = <<EOF
apiVersion: iamauthenticator.k8s.aws/v1alpha1
kind: IAMIdentityMapping
metadata:
  name: kubernetes-admin
spec:
  arn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.eks-admin.name}
  username: kubernetes-admin
  groups:
    - system:masters
EOF
}

resource "null_resource" "eks-admin" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${data.template_file.eks-admin.rendered}"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(data.template_file.eks-admin.rendered)
  }
  depends_on = [aws_iam_role.eks-admin, null_resource.eks-admin-crd]
}

resource "aws_iam_role_policy" "eks-node-eip" {
  name = "${var.cluster_id}-node-eip"
  role = var.worker_iam_role_name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:DescribeAddresses",
      "ec2:DisassociateAddress",
      "ec2:AssociateAddress"    ],
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatch-eks" {
  role = var.worker_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "k8s-autoscaler" {
  name = "${var.cluster_id}-k8s-autoscaler"
  role = var.worker_iam_role_name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ],
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_role_policy" "k8s-csi" {
  name = "${var.cluster_id}-k8s-csi"
  role = var.worker_iam_role_name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "k8s-logs" {
  name = "${var.cluster_id}-k8s-logs"
  role = var.worker_iam_role_name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:ListTagsLogGroup",
        "logs:DescribeQueries",
        "logs:GetLogRecord",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:DescribeSubscriptionFilters",
        "logs:StartQuery",
        "logs:DescribeMetricFilters",
        "logs:StopQuery",
        "logs:TestMetricFilter",
        "logs:GetLogDelivery",
        "logs:ListLogDeliveries",
        "logs:DescribeExportTasks",
        "logs:GetQueryResults",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "logs:GetLogGroupFields",
        "logs:DescribeResourcePolicies",
        "logs:DescribeDestinations"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
