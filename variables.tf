variable "cluster_id" {
  default = ""
}

variable "cluster_domain" {
  default = ""
}

variable "cluster_ca_certificate" {
  default = ""
}

variable "worker_iam_role_name" {
 default = ""
}

variable "kubeconfig_filename" {
  default = ""
}

variable "dashboard_oauth_config" {
  type = "map"
  default = {}
}

variable "registry_config" {
  type = "map"
  default = {}
}

variable "logging_config" {
  type = "map"
  default = {}
}

variable "metric_config" {
  type = "map"
  default = {}
}
