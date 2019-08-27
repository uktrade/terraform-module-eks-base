locals {
  cloudwatch_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/kubernetes-monitoring"
  statsd_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/statsd"
  local_temp = "${path.root}/.terraform/temp"
}

resource "null_resource" "temp" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.local_temp}"
  }
  triggers {
    build_number = "${timestamp()}"
  }
}

resource "null_resource" "cloudwatch-ns-temp" {
  provisioner "local-exec" {
    command = "wget -O ${local.local_temp}/cloudwatch-namespace.yaml ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.temp"]
}

resource "null_resource" "cloudwatch-ns" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(file("${local.local_temp}/cloudwatch-namespace.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns-temp"]
}

resource "null_resource" "cloudwatch-config-temp" {
  provisioner "local-exec" {
    command = "wget -O ${local.local_temp}/cwagent-configmap.yaml ${local.cloudwatch_url}/cwagent-configmap.yaml"
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.temp"]
}

resource "null_resource" "cloudwatch-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(file("${local.local_temp}/cwagent-configmap.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns", "null_resource.cloudwatch-config-temp"]
}

data "template_file" "cloudwatch-config-patch" {
  template = <<EOF
data:
  cwagentconfig.json: |
    {
      "logs": {
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
    build_number = "${sha1(file("${local.local_temp}/cwagent-configmap.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns", "null_resource.cloudwatch-config-temp"]
}

resource "null_resource" "cloudwatch-sa-temp" {
  provisioner "local-exec" {
    command = "wget -O ${local.local_temp}/cwagent-serviceaccount.yaml ${local.cloudwatch_url}/cwagent-serviceaccount.yaml"
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.temp"]
}

resource "null_resource" "cloudwatch-sa" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-serviceaccount.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(file("${local.local_temp}/cwagent-serviceaccount.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns", "null_resource.cloudwatch-sa-temp"]
}

resource "null_resource" "cloudwatch-daemonset-temp" {
  provisioner "local-exec" {
    command = "wget -O ${local.local_temp}/cwagent-daemonset.yaml ${local.cloudwatch_url}/cwagent-daemonset.yaml"
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.temp"]
}

resource "null_resource" "cloudwatch-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(file("${local.local_temp}/cwagent-daemonset.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns", "null_resource.cloudwatch-sa", "null_resource.cloudwatch-daemonset-temp"]
}

resource "null_resource" "cloudwatch-statsd-config-temp" {
  provisioner "local-exec" {
    command = "wget -O ${local.local_temp}/cwagent-statsd-configmap.yaml ${local.statsd_url}/cwagent-statsd-configmap.yaml"
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.temp"]
}

resource "null_resource" "cloudwatch-statsd-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(file("${local.local_temp}/cwagent-statsd-configmap.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns", "null_resource.cloudwatch-statsd-config-temp"]
}

resource "null_resource" "cloudwatch-statsd-daemonset-temp" {
  provisioner "local-exec" {
    command = "wget -O ${local.local_temp}/cwagent-statsd-daemonset.yaml ${local.statsd_url}/cwagent-statsd-daemonset.yaml"
  }
  triggers {
    build_number = "${timestamp()}"
  }
  depends_on = ["null_resource.temp"]
}

resource "null_resource" "cloudwatch-statsd-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(file("${local.local_temp}/cwagent-statsd-daemonset.yaml"))}"
  }
  depends_on = ["null_resource.cloudwatch-ns", "null_resource.cloudwatch-statsd-daemonset-temp"]
}
