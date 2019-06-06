locals {
  s3_bucket = "cloudwatch-agent-k8s-yamls"
  cloudwatch_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/kubernetes-monitoring"
  fluentd_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/fluentd/fluentd.yml"
  statsd_url = "https://s3.amazonaws.com/cloudwatch-agent-k8s-yamls/statsd"
}

provider "aws" {
  alias = "aws-k8s"
  region = "us-east-1"
}

data "aws_s3_bucket_object" "cloudwatch-ns" {
  provider = "aws.aws-k8s"
  bucket = "${local.s3_bucket}"
  key = "kubernetes-monitoring/cloudwatch-namespace.yaml"
}

resource "null_resource" "cloudwatch-ns" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cloudwatch-namespace.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.aws_s3_bucket_object.cloudwatch-ns.body)}"
  }
}

data "http" "cloudwatch-config" {
  url = "${local.cloudwatch_url}/cwagent-configmap.yaml"
}

resource "null_resource" "cloudwatch-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.cloudwatch-config.body)}"
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
    build_number = "${sha1(data.http.cloudwatch-config.body)}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

data "http" "cloudwatch-daemonset" {
  url = "${local.cloudwatch_url}/cwagent-daemonset.yaml"
}

resource "null_resource" "cloudwatch-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.cloudwatch_url}/cwagent-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.cloudwatch-daemonset.body)}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

data "http" "cloudwatch-fluentd" {
  url = "${local.fluentd_url}"
}

resource "null_resource" "cloudwatch-fluentd" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.fluentd_url}"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.cloudwatch-daemonset.body)}"
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

data "http" "cloudwatch-statsd-config" {
  url = "${local.statsd_url}/cwagent-statsd-configmap.yaml"
}

resource "null_resource" "cloudwatch-statsd-config" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-configmap.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.cloudwatch-statsd-config.body)}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}

data "http" "cloudwatch-statsd-daemonset" {
  url = "${local.statsd_url}/cwagent-statsd-daemonset.yaml"
}

resource "null_resource" "cloudwatch-statsd-daemonset" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.statsd_url}/cwagent-statsd-daemonset.yaml"
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.http.cloudwatch-statsd-daemonset.body)}"
  }
  depends_on = ["null_resource.cloudwatch-ns"]
}
