locals {
  cloudwatch_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/kubernetes-monitoring"
  fluentd_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/fluentd/fluentd.yml"
  statsd_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/statsd"
}

resource "null_resource" "cloudwatch-ns" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
}

resource "null_resource" "cloudwatch-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

data "template_file" "cloudwatch-config-patch" {
  template = <<EOF
data:
  cwagentconfig.json: |
    {
      "structuredlogs": {
        "metrics_collected": {
          "kubernetes": {
            "cluster_name": "${var.cluster_id}",
            "metrics_collection_interval": 60
          }
        },
        "force_flush_interval": 5
      }
    }
EOF
}

resource "null_resource" "cloudwatch-config-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n amazon-cloudwatch patch configmap cwagentconfig -p '${data.template_file.cloudwatch-config-patch.rendered}'
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

resource "null_resource" "cloudwatch-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

resource "null_resource" "cloudwatch-fluentd" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.fluentd_url}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

resource "kubernetes_config_map" "cloudwatch-fluentd" {
  metadata {
    name = "cluster-info"
    namespace = "amazon-cloudwatch"
  }
  data {
    cluster.name = "${var.cluster_id}"
    logs.region = "${data.aws_region.current.name}"
  }
}

resource "null_resource" "cloudwatch-statsd-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

resource "null_resource" "cloudwatch-statsd-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}
