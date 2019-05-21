provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

locals {
  metrics_url = "https://raw.githubusercontent.com/aws-samples/aws-workshop-for-kubernetes/master/02-path-working-with-clusters/201-cluster-monitoring/templates/prometheus"
}

resource "null_resource" "prometheus-init" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "template_file" "prometheus-patch_1" {
  template = <<EOF
rules:
- apiGroups:
  - extensions
  resources:
  - thirdpartyresources
  verbs:
  - "*"
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - "*"
- apiGroups:
  - monitoring.coreos.com
  resources:
  - alertmanagers
  - prometheuses
  - servicemonitors
  - prometheusrules
  verbs:
  - "*"
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs: ["*"]
- apiGroups: [""]
  resources:
  - configmaps
  - secrets
  verbs: ["*"]
- apiGroups: [""]
  resources:
  - pods
  verbs: ["list", "delete", "watch"]
- apiGroups: [""]
  resources:
  - services
  - endpoints
  verbs: ["get", "create", "update"]
- apiGroups: [""]
  resources:
  - nodes
  verbs: ["list", "watch"]
- apiGroups: [""]
  resources:
  - namespaces
  verbs: ["list"]
- apiGroups: [""]
  resources:
  - services
  verbs: ["list", "get", "watch"]
- apiGroups: [""]
  resources:
  - endpoints
  verbs: ["list", "get", "watch"]
EOF
}

resource "null_resource" "prometheus-patch_1" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch clusterrole prometheus-operator -p '${data.template_file.prometheus-patch_1.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "template_file" "prometheus-patch_2" {
  template = <<EOF
spec:
  template:
    spec:
      containers:
      - name: prometheus-operator
        image: quay.io/coreos/prometheus-operator:v0.30.0
EOF
}

resource "null_resource" "prometheus-patch_2" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch -n monitoring deployment prometheus-operator -p '${data.template_file.prometheus-patch_2.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "prometheus" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "template_file" "prometheus-ingress" {
  template = <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    k8s-app: prometheus-operator
spec:
  rules:
  - host: status.${var.cluster_domain}
    http:
      paths:
      - path: /
        backend:
          serviceName: prometheus-operated
          servicePort: 9090
EOF
}

resource "null_resource" "prometheus-ingress" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n monitoring apply -f -
${data.template_file.prometheus-ingress.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "grafana" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/grafana-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "template_file" "grafana-patch" {
  template = <<EOF
spec:
  template:
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:6.1.6
EOF
}

resource "null_resource" "grafana-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch -n monitoring deployment grafana -p '${data.template_file.grafana-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "template_file" "grafana-ingress" {
  template = <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  rules:
  - host: metrics.${var.cluster_domain}
    http:
      paths:
      - path: /
        backend:
          serviceName: grafana
          servicePort: 3000
EOF
}

resource "null_resource" "grafana-ingress" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n monitoring apply -f -
${data.template_file.grafana-ingress.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "kubernetes_service" "kubelet-metrics" {
  metadata {
    name = "kubelet"
    namespace = "kube-system"
    labels {
      k8s-app = "kubelet"
    }
  }
  spec {
    type = "ClusterIP"
    port {
      name = "https-metrics"
      port = 10250
      target_port = 10250
    }
  }
}
