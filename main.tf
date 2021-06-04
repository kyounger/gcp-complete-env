
data "google_client_config" "default" {}

locals {
  regions = [for cluster in var.clusters : cluster.region]
  primary_subnets = [for name, def in var.clusters : {
    subnet_name = "${name}-subnet-primary"
    subnet_ip = def.primary
    subnet_region = def.region
    subnet_private_access = true
  }]
  secondary_ranges = { for name, def in var.clusters : "${name}-subnet-primary" => [
    {
      range_name = "${name}-subnet-pods"
      ip_cidr_range = def.pods
    },
    {
      range_name = "${name}-subnet-services"
      ip_cidr_range = def.services
    },
  ]}
}

module "gcp-network" {
  source = "terraform-google-modules/network/google"
  version = "3.2.2"

  project_id = var.project_id
  network_name = var.proxy_subdomain
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
  subnets = local.primary_subnets
  secondary_ranges = local.secondary_ranges
}

module "cloud_router" {
  for_each = toset(local.regions)

  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 0.4"
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

  source = "./clusters"

  cluster_name = each.key
  global_network_name = module.gcp-network.network_name
  ip_range_pods_name = "${each.key}-subnet-pods"
  ip_range_services_name = "${each.key}-subnet-services"
  master_ipv4_cidr_block = each.value.k8s_api
  node_pools = each.value.node_pools
  owner_label = var.owner_label
  project_id = var.project_id
  region = each.value.region
  subnetwork_name = "${each.key}-subnet-primary"
  zones = each.value.zones
}

// ----------------------------------------------------------------------------
// Static IP for proxy_subdomain
// ----------------------------------------------------------------------------
resource "google_compute_address" "static" {
  provider = google-beta
  project = var.project_id
  name = "load-balancer-${var.proxy_subdomain}"
  address_type = "EXTERNAL"
  region = var.proxy_region
  labels = {
    "owner": var.owner_label
  }
}

// ----------------------------------------------------------------------------
// DNS configuration
// ----------------------------------------------------------------------------
resource "google_dns_record_set" "hostname" {
  project = var.project_id
  name = "${var.proxy_subdomain}.${data.google_dns_managed_zone.managed_zone.dns_name}"
  type = "A"
  ttl  = 300
  managed_zone = data.google_dns_managed_zone.managed_zone.name
  rrdatas = [google_compute_address.static.address]
}

data "google_dns_managed_zone" "managed_zone" {
  name = var.managed_zone_name
  project = var.project_id
}

