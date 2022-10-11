
data "google_client_config" "default" {}

locals {
  regions = [for cluster in var.clusters : cluster.region]
  primary_subnets = [for name, def in var.clusters : {
    subnet_name           = "${name}-subnet-primary"
    subnet_ip             = def.primary
    subnet_region         = def.region
    subnet_private_access = true
  }]
  secondary_ranges = { for name, def in var.clusters : "${name}-subnet-primary" => [
    {
      range_name    = "${name}-subnet-pods"
      ip_cidr_range = def.pods
    },
    {
      range_name    = "${name}-subnet-services"
      ip_cidr_range = def.services
    },
  ] }
}

module "gcp-network" {
  source  = "terraform-google-modules/network/google"
  version = "5.2.0"

  project_id              = var.project_id
  network_name            = var.proxy_subdomain
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  subnets                 = local.primary_subnets
  secondary_ranges        = local.secondary_ranges
  firewall_rules = [{
    name                    = "allow-ingress"
    description             = null
    direction               = "INGRESS"
    priority                = 1000
    ranges                  = ["10.0.0.0/8"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["1-65535"]
      }, {
      protocol = "udp"
      ports    = ["1-65535"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

module "cloud_router" {
  for_each = toset(local.regions)

  source  = "terraform-google-modules/cloud-router/google"
  version = "3.0.0"
  project = var.project_id
  name    = "${var.owner_label}${each.value}-router"
  network = module.gcp-network.network_name
  region  = each.value

  nats = [{
    name = "${var.owner_label}${each.value}-gateway"
  }]
}


module "gke-clusters" {
  for_each = var.clusters
  source   = "./clusters"

  cluster_name           = each.key
  global_network_name    = module.gcp-network.network_name
  ip_range_pods_name     = "${each.key}-subnet-pods"
  ip_range_services_name = "${each.key}-subnet-services"
  master_ipv4_cidr_block = each.value.k8s_api
  node_pools             = each.value.node_pools
  owner_label            = var.owner_label
  project_id             = var.project_id
  region                 = each.value.region
  subnetwork_name        = "${each.key}-subnet-primary"
  zones                  = each.value.zones

  depends_on = [
    module.gcp-network
  ]

}

// ----------------------------------------------------------------------------
// Static IP for proxy_subdomain
// ----------------------------------------------------------------------------
module "address-fe" {
  source  = "terraform-google-modules/address/google"
  version = "3.1.1"

  names        = ["static-ip-${var.proxy_subdomain}"]
  global       = true
  project_id   = var.project_id
  region       = null
  address_type = "EXTERNAL"
}

// ----------------------------------------------------------------------------
// DNS configuration
// ----------------------------------------------------------------------------
resource "google_dns_record_set" "hostname" {
  project      = var.dns_managed_zone_project_id
  name         = "${var.proxy_subdomain}.${data.google_dns_managed_zone.managed_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.managed_zone.name
  rrdatas      = [module.address-fe.addresses[0]]
}

data "google_dns_managed_zone" "managed_zone" {
  name    = var.managed_zone_name
  project = var.dns_managed_zone_project_id
}


// 1. add forwarding rule (kyoungertest-fe-1) -- attach IP address
// 2. add target proxy (kyoungertest-target-proxy) -- attach url map / host path and rules (kyoungertest)??
// 3. add backend services

