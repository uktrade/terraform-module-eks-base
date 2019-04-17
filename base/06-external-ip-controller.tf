data "aws_subnet" "eks-external-ip" {
  count = "${length(var.vpc_public_subnets)}"
  id = "${element(var.vpc_public_subnets, count.index)}"
}

resource "aws_network_interface" "eks-external-ip" {
  count = "${length(var.vpc_public_subnets)}"
  subnet_id = "${element(var.vpc_public_subnets, count.index)}"
  tags {
    Stack = "${var.cluster_domain}"
    "kubernetes.io/cluster/${var.cluster_id}" = "shared"
    network = "public"
    availability_zone = "${element(data.aws_subnet.eks-external-ip.*.availability_zone, count.index)}"
  }
}

data "template_file" "eks-external-ip" {
  template = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: externalipcontroller
---
# https://github.com/Mirantis/k8s-externalipcontroller/blob/master/examples/auth.yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: externalipcontroller
subjects:
- kind: ServiceAccount
  name: externalipcontroller
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
# https://github.com/Mirantis/k8s-externalipcontroller/blob/master/examples/simple/externalipcontroller.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: externalipcontroller
spec:
  # only single replica allowed until we will add protection against fighting for
  # same ip, this agent will probably become daemonset at that point
  replicas: 1
  template:
    metadata:
      labels:
        app: externalipcontroller
    spec:
      hostNetwork: true
      nodeSelector:
        network: public
      serviceAccount: externalipcontroller
      containers:
      - env:
        - name: HOST_INTERFACE
          valueFrom:
            configMapKeyRef:
              key: iface
              name: externalipcontroller-config
        image: mirantis/k8s-externalipcontroller
        imagePullPolicy: IfNotPresent
        name: externalipcontroller
        securityContext:
          privileged: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app: externalipcontroller
  name: externalipcontroller-config
data:
  iface: eth0
EOF
}

resource "null_resource" "k8s-external-ip" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system apply -f -
${data.template_file.eks-external-ip.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
