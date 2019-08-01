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

variable "logging_config" {
  type = "map"
  default = {}
}

variable "helm_release" {
  type = "map"
  default = {}
}
