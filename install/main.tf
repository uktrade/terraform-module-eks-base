module "eks-base" {
  source = "https://github.com/uktrade/terraform-module-eks-base.git//01-base"
  cluster_id = "${var.cluster_id}"
  worker_iam_role_name = "${var.worker_iam_role_name}"
}
