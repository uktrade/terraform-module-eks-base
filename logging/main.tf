resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

data "template_file" "fluentd" {
  template = <<EOF
elasticsearch:
  scheme: https
  host: ${var.logging_config["es_host"]}
  port: ${var.logging_config["es_port"]}
  logstash_prefix: "${var.cluster_name}-k8s"
configMaps:
  output.conf: |
    # Enriches records with Kubernetes metadata
    <filter kubernetes.**>
      @type kubernetes_metadata
    </filter>
    <match **>
      @id elasticsearch
      @type elasticsearch
      @log_level info
      include_tag_key true
      type_name _doc
      host "#{ENV['OUTPUT_HOST']}"
      port "#{ENV['OUTPUT_PORT']}"
      scheme "#{ENV['OUTPUT_SCHEME']}"
      ssl_version "#{ENV['OUTPUT_SSL_VERSION']}"
      ssl_verify false
      user ${var.logging_config["es_user"]}
      password ${var.logging_config["es_pass"]}
      logstash_format true
      logstash_prefix "#{ENV['LOGSTASH_PREFIX']}"
      rollover_index true
      enable_ilm true
      ilm_policy_id default-index-policy
      reconnect_on_error true
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        retry_type exponential_backoff
        flush_thread_count 2
        flush_interval 5s
        retry_forever
        retry_max_interval 30
        chunk_limit_size "#{ENV['OUTPUT_BUFFER_CHUNK_LIMIT']}"
        queue_limit_length "#{ENV['OUTPUT_BUFFER_QUEUE_LIMIT']}"
        overflow_action block
      </buffer>
    </match>
EOF
}

resource "helm_release" "fluentd" {
  name = "fluentd-elasticsearch"
  namespace = "logging"
  repository = "stable"
  chart = "fluentd-elasticsearch"
  version = var.helm_release["fluentd-elasticsearch"]
  values = ["${data.template_file.fluentd.rendered}"]
  depends_on = [kubernetes_namespace.logging]
}
