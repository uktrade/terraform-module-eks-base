module "eks-base" {
  source = "github.com/uktrade/terraform-module-eks-base//base"
  cluster_id = "${var.cluster_id}"
  cluster_domain = "${var.cluster_domain}"
  worker_iam_role_name = "${var.worker_iam_role_name}"
  kubeconfig_filename = "${var.kubeconfig_filename}"
  vpc_public_subnets = "${var.vpc_public_subnets}"
  vpc_private_subnets = "${var.vpc_private_subnets}"
  vpc_intra_subnets = "${var.vpc_intra_subnets}"
}
