module "eks-base" {
  source = "github.com/uktrade/terraform-module-eks-base//base"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  worker_iam_role_name = "${var.worker_iam_role_name}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
}
