variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "global_network_name" {
  type = string
}

variable "subnetwork_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "master_ipv4_cidr_block" {
  type = string
}

variable "ip_range_pods_name" {
  type = string
}

variable "ip_range_services_name" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "node_pools" {
  type = any
}

variable "owner_label" {
  type = string
}