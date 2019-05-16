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
  cluster_ca_certificate = "${var.cluster_certificate_authority_data}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
  dashboard_oauth_config = "${var.dashboard_oauth_config}"
}

# module "eks-registry" {
#   source = "github.com/uktrade/terraform-module-eks-base//registry"
#   cluster_id = "${var.cluster_id}"
#   cluster_domain = "${var.cluster_domain}"
#   kubeconfig_filename = "${var.kubeconfig_filename}"
#   registry_oauth_config = "${var.registry_oauth_config}"
# }

# module "eks-logging" {
#   source = "github.com/uktrade/terraform-module-eks-base//logging"
#   cluster_id = "${var.cluster_id}"
#   cluster_domain = "${var.cluster_domain}"
#   kubeconfig_filename = "${var.kubeconfig_filename}"
# }
