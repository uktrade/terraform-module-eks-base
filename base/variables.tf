variable "cluster_id" {
  default = ""
}

variable "cluster_domain" {
  default = ""
}

variable "worker_iam_role_name" {
 default = ""
}

variable "kubeconfig_filename" {
  default = ""
}

variable "vpc_public_subnets" {
  type = "list"
  default = []
}

variable "vpc_private_subnets" {
  type = "list"
  default = []
}

variable "vpc_intra_subnets" {
  type = "list"
  default = []
}
