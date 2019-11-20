locals {
  cloudwatch_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/kubernetes-monitoring"
  statsd_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/statsd"
  local_temp = "${path.root}/.terraform/temp"
}

module "cloudwatch-ns" {
  source  = "matti/outputs/shell"
  command = "curl -Lfs ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
}

resource "null_resource" "cloudwatch-ns" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-ns.stdout)
  }
}

module "cloudwatch-config" {
  source  = "matti/outputs/shell"
  command = "curl -Lfs ${local.cloudwatch_url}/cwagent-configmap.yaml"
}

resource "null_resource" "cloudwatch-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-configmap.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-config.stdout)
  }
  depends_on = [null_resource.cloudwatch-ns]
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
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-config.stdout)
  }
  depends_on = [null_resource.cloudwatch-ns, null_resource.cloudwatch-config]
}

module "cloudwatch-sa" {
  source  = "matti/outputs/shell"
  command = "curl -Lfs ${local.cloudwatch_url}/cloudwatch-serviceaccount.yaml"
}

resource "null_resource" "cloudwatch-sa" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-serviceaccount.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-sa.stdout)
  }
  depends_on = [null_resource.cloudwatch-ns]
}

module "cloudwatch-daemonset" {
  source  = "matti/outputs/shell"
  command = "curl -Lfs ${local.cloudwatch_url}/cwagent-daemonset.yaml"
}

resource "null_resource" "cloudwatch-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-daemonset.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-daemonset.stdout)
  }
  depends_on = [null_resource.cloudwatch-ns, null_resource.cloudwatch-sa]
}

module "cloudwatch-statsd-config" {
  source  = "matti/outputs/shell"
  command = "curl -Lfs ${local.cloudwatch_url}/cwagent-statsd-configmap.yaml"
}

resource "null_resource" "cloudwatch-statsd-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-configmap.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-statsd-config.stdout)
  }
  depends_on = [null_resource.cloudwatch-ns]
}

module "cloudwatch-statsd-daemonset" {
  source  = "matti/outputs/shell"
  command = "curl -Lfs ${local.cloudwatch_url}/cwagent-statsd-daemonset.yaml"
}

resource "null_resource" "cloudwatch-statsd-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-daemonset.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_filename
    }
  }
  triggers = {
    build_number = sha1(module.cloudwatch-statsd-daemonset.stdout)
  }
  depends_on = [null_resource.cloudwatch-ns]
}
