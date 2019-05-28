locals {
  cloudwatch_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/kubernetes-monitoring"
}

resource "null_resource" "cloudwatch-ns" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}

resource "null_resource" "cloudwatch-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
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
}

resource "null_resource" "cloudwatch-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
}
