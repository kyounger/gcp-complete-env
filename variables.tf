variable "project_id" {
  type = string
}

variable "owner_label" {
  type = string
}

variable "managed_zone_name" {
  type = string
}

variable "proxy_subdomain" {
  type = string
}

variable "proxy_region" {
  type = string
}

variable "clusters" {
  type = map(object({
    region = string
    zones = list(string)
    primary = string
    pods = string
    services = string
    k8s_api = string
    node_pools = list(map(string))
  }))
}


