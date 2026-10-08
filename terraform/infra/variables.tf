variable "yc_cloud_id" {
  type    = string
  default = "b1gtusuaqn60dr8olfid"
}

variable "yc_folder_id" {
  type    = string
  default = "b1grvjpek3up0eujvbn7"
}

variable "yc_zone" {
  type    = string
  default = "ru-central1-a"
}

variable "vpc_name" {
  type    = string
  default = "diploma-vpc"
}

variable "k8s_cluster_name" {
  type    = string
  default = "diploma-k8s"
}

variable "k8s_node_group_name" {
  type    = string
  default = "diploma-k8s-nodes"
}

variable "registry_name" {
  type    = string
  default = "diploma-registry"
}
