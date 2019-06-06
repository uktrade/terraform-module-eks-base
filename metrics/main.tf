provider "kubernetes" {
  config_path = "${var.kubeconfig_filename}"
}

locals {
  metrics_url = "https://raw.githubusercontent.com/aws-samples/aws-workshop-for-kubernetes/master/02-path-working-with-clusters/201-cluster-monitoring/templates"
}

data "http" "prometheus-init" {
  url = "${local.metrics_url}/prometheus/prometheus-bundle.yaml"
}

resource "null_resource" "prometheus-init" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus/prometheus-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus-init.body)}"
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
  - services
  - endpoints
  verbs: ["list", "get", "watch", "update"]
- apiGroups: [""]
  resources:
  - namespaces
  - nodes
  - pods
  verbs: ["list", "get", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
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
  triggers {
    build_number = "${sha1(data.http.prometheus-init.body)}"
  }
  depends_on = ["null_resource.prometheus-init"]
}

data "template_file" "prometheus-patch_2" {
  template = <<EOF
spec:
  template:
    spec:
      containers:
      - name: prometheus-operator
        image: quay.io/coreos/prometheus-operator:v0.29.0
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
  triggers {
    build_number = "${sha1(data.http.prometheus-init.body)}"
  }
  depends_on = ["null_resource.prometheus-init"]
}

data "http" "prometheus" {
  url = "${local.metrics_url}/prometheus/prometheus.yaml"
}

resource "null_resource" "prometheus" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus/prometheus.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus.body)}"
  }
}

data "template_file" "prometheus-patch" {
  template = <<EOF
spec:
  template:
    spec:
      containers:
      - name: prometheus
        image: quay.io/prometheus/prometheus:v2.10.0
      - name: prometheus-config-reloader
        image: quay.io/coreos/prometheus-config-reloader:v0.30.0
EOF
}

resource "null_resource" "prometheus-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch -n monitoring statefulset prometheus-prometheus -p '${data.template_file.prometheus-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus.body)}"
  }
  depends_on = ["null_resource.prometheus"]
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
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      rewrite ^/$ /targets last;
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
  triggers {
    build_number = "${sha1(data.template_file.prometheus-ingress.rendered)}"
  }
}

data "http" "grafana" {
  url = "${local.metrics_url}/prometheus/grafana-bundle.yaml"
}

resource "null_resource" "grafana" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/prometheus/grafana-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.grafana.body)}"
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
  triggers {
    build_number = "${sha1(data.http.grafana.body)}"
  }
  depends_on = ["null_resource.grafana"]
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
  triggers {
    build_number = "${sha1(data.template_file.grafana-ingress.rendered)}"
  }
}

resource "null_resource" "kube-state-metrics-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n monitoring delete ServiceAccount/kube-state-metrics ClusterRoleBinding/kube-state-metrics Deployment/kube-state-metrics Service/kube-state-metrics ServiceMonitor/kube-state-metrics
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus.body)}"
  }
  depends_on = ["null_resource.prometheus"]
}

resource "helm_release" "kube-state-metrics" {
  name = "kube-state-metrics"
  namespace = "monitoring"
  repository = "stable"
  chart = "kube-state-metrics"
  depends_on = ["null_resource.kube-state-metrics-patch"]
}

data "template_file" "node-exporter-patch" {
  template = <<EOF
spec:
  template:
    spec:
      containers:
      - name: node-exporter
        image: quay.io/prometheus/node-exporter:v0.18.0
EOF
}

resource "null_resource" "node-exporter-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch -n monitoring daemonset node-exporter -p '${data.template_file.node-exporter-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus.body)}"
  }
  depends_on = ["null_resource.prometheus"]
}

data "template_file" "alertmanager-patch" {
  template = <<EOF
spec:
  template:
    spec:
      containers:
      - name: alertmanager
        image: quay.io/prometheus/alertmanager:v0.17.0
EOF
}

resource "null_resource" "alertmanager-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch -n monitoring statefulset alertmanager-main -p '${data.template_file.alertmanager-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus.body)}"
  }
  depends_on = ["null_resource.prometheus"]
}

data "template_file" "servicemonitor-kubelet-patch" {
  template = <<EOF
{
  "spec": {
    "endpoints": [
      {
        "port": "https-metrics",
        "scheme": "https",
        "interval": "30s",
        "bearerTokenFile": "/var/run/secrets/kubernetes.io/serviceaccount/token",
        "tlsConfig": {
          "caFile": "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        }
      },
      {
        "honorLabels": true,
        "interval": "30s",
        "port": "cadvisor"
      }
    ]
  }
}
EOF
}

resource "null_resource" "servicemonitor-kubelet-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl patch -n monitoring servicemonitor kubelet --type merge -p '${data.template_file.servicemonitor-kubelet-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.prometheus.body)}"
  }
  depends_on = ["null_resource.prometheus"]
}
