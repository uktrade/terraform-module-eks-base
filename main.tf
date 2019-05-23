module "eks-base" {
  source = "github.com/uktrade/terraform-module-eks-base//base"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  worker_iam_role_name = "${var.worker_iam_role_name}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
}

module "eks-dashboard" {
  source = "github.com/uktrade/terraform-module-eks-base//dashboard"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  cluster_ca_certificate = "${var.cluster_ca_certificate}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
  dashboard_oauth_config = "${var.dashboard_oauth_config}"
}

module "eks-registry" {
  source = "github.com/uktrade/terraform-module-eks-base//docker-registry"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
  registry_config = "${var.registry_config}"
}

module "eks-metrics" {
  source = "github.com/uktrade/terraform-module-eks-base//metrics"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
}


module "eks-logging" {
  source = "github.com/uktrade/terraform-module-eks-base//logging"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
  logging_config = "${var.logging_config}"
}
