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
      containers:
      - name: externalipcontroller
        image: mirantis/k8s-externalipcontroller
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        env:
        - name: HOST_INTERFACE
          valueFrom:
            configMapKeyRef:
              key: iface
              name: externalipcontroller-config
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
