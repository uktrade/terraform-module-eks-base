locals {
  cloudwatch_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/kubernetes-monitoring"
}

data "http" "cloudwatch-ns" {
  url = "${local.cloudwatch_url}/cloudwatch-namespace.yaml"
}

resource "null_resource" "cloudwatch-ns" {
  provisioner "local-exec" {
    command = "kubectl apply ${data.http.cloudwatch-ns.body}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

data "http" "cloudwatch-config" {
  url = "${local.cloudwatch_url}/cwagent-configmap.yaml"
}

resource "null_resource" "cloudwatch-config" {
  provisioner "local-exec" {
    command = "kubectl apply ${data.http.cloudwatch-config.body}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

template "template_file" "cloudwatch-config-patch" {
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
}

data "http" "cloudwatch-daemonset" {
  url = "${local.cloudwatch_url}/cwagent-daemonset.yaml"
}

resource "null_resource" "cloudwatch-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply ${data.http.cloudwatch-daemonset.body}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
