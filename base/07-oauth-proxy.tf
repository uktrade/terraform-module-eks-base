data "template_file" "oauth-proxy-values" {
  template = <<EOF
config:
  configFile: |-
    provider = "${var.dashboard_oauth_config["provider"]}"
    client_id = "${var.dashboard_oauth_config["client_id"]}"
    client_secret = "${var.dashboard_oauth_config["client_secret"]}"
    github_org = "${var.dashboard_oauth_config["github_org"]}"
    github_team = "${var.dashboard_oauth_config["github_team"]}"
    email_domains = ["*"]
EOF
}

resource "helm_release" "oauth-proxy" {
  name = "oauth2-proxy"
  namespace = "kube-system"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart = "oauth2-proxy"
  version = "0.12.1"
  values = ["${data.template_file.oauth-proxy-values.rendered}"]
}
