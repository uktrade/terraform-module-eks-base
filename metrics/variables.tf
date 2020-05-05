variable "cluster_name" {
  default = ""
}

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

variable "metric_config" {
  type = map(string)
  default = {}
}

variable "helm_release" {
  type = map(string)
  default = {}
}
