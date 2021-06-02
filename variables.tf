variable "project_id" {
  type = string
}

variable "owner_label" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
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

variable "managed_zone_name" {
  type = string
}

variable "subdomain" {
  type = string
}

variable "node_pools" {
  type = any
}
