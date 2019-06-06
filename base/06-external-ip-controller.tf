locals {
  externalipcontroller-release = "master"
  externalipcontroller-url = "https://raw.githubusercontent.com/Mirantis/k8s-externalipcontroller/${local.externalipcontroller-release}/examples/simple/externalipcontroller.yaml"
}

resource "kubernetes_service_account" "eks-externalipcontroller" {
  metadata {
    name = "externalipcontroller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "eks-externalipcontroller" {
  metadata {
    name = "externalipcontroller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "externalipcontroller"
    namespace = "kube-system"
  }
}

resource "kubernetes_config_map" "eks-externalipcontroller" {
  metadata {
    name = "externalipcontroller-config"
    namespace = "kube-system"
    labels {
      app = "externalipcontroller"
    }
  }
  data {
    iface = "eth0"
  }
}

# Add custom configs to default deployment spec
# https://github.com/Mirantis/k8s-externalipcontroller/blob/master/examples/simple/externalipcontroller.yaml
data "template_file" "eks-external-ip" {
  template = <<EOF
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
  triggers {
    build_number = "${sha1(data.template_file.eks-external-ip.rendered)}"
  }
}
