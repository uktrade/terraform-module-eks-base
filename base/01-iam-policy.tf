resource "aws_iam_role_policy" "eks-node-eip" {
  name = "${var.cluster_id}-node-eip"
  role = "${var.worker_iam_role_name}"
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
  role = "${var.worker_iam_role_name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
