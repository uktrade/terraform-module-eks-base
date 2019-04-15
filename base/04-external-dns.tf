data "aws_route53_zone" "k8s-dns" {
  name = "${var.cluster_domain}"
}

resource "aws_iam_role_policy" "eks-route53" {
  name = "${var.cluster_id}-route53"
  role = "${var.worker_iam_role_name}"
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

resource "null_resource" "k8s-external-dns-policy" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system apply -f -
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: k8s-api
spec:
  selector: name == 'kubernetes'
  types:
    - Ingress
    - Egress
  ingress:
    - action: Allow
      protocol: TCP
      source:
        namespaceSelector: name == 'kube-system'
      destination:
        ports:
          - 443
  egress:
    - action: Allow
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "template_file" "eks-external-dns" {
  template = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: external-dns
spec:
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.opensource.zalan.do/teapot/external-dns:latest
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=${var.cluster_domain}
        - --zone-id-filter=${data.aws_route53_zone.k8s-dns.zone_id}
        - --provider=aws
        - --policy=sync
        - --aws-zone-type=public
        - --registry=txt
        - --txt-owner-id=${var.cluster_id}
EOF
}

resource "null_resource" "k8s-external-dns" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system apply -f -
${data.template_file.eks-external-dns.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
