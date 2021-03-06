variable "cluster_name" {
  default = ""
}

variable "cluster_id" {
  default = ""
}

variable "worker_iam_role_name" {
 default = ""
}

variable "kubeconfig_filename" {
  default = ""
}

variable "logging_config" {
  type = map(string)
  default = {}
}

variable "helm_release" {
  type = map(string)
  default = {}
}

variable "eks_extra_config" {
  type    = any
  default = {}
}
