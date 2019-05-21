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
  - monitoring.coreos.com
  resources:
  - alertmanagers
  - prometheuses
  - servicemonitors
  - prometheusrules
  verbs:
  - "*"
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

resource "null_resource" "grafana" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.metrics_url}/grafana-bundle.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
