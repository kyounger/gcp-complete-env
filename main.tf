
data "google_client_config" "default" {}

module "gcp-network" {
  source = "terraform-google-modules/network/google"
  version = "3.2.2"

  project_id = var.project_id
  network_name = var.cluster_name
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name = "subnet1"
      subnet_ip = "10.0.0.0/16"
      subnet_region = var.region
      subnet_private_access = true
    },
  ]
  secondary_ranges = {
    "subnet1" = [
      {
        range_name = var.ip_range_pods_name
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name = var.ip_range_services_name
        ip_cidr_range = "10.2.0.0/16"
      },
    ]
  }
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 0.4"
  project = var.project_id
  name    = "${var.cluster_name}-router"
  network = module.gcp-network.network_name
  region  = var.region

  nats = [{
    name = "${var.cluster_name}-gateway"
  }]
}


#------- kubernetes stuff ---------#

provider "kubernetes" {
  host = "https://${module.gke.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "gke" {
  source = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "14.3.0"

  project_id = var.project_id
  name = var.cluster_name
  regional = true
  zones = var.zones
  region = var.region
  enable_private_endpoint   = false
  enable_private_nodes      = true
  remove_default_node_pool  = true
  master_ipv4_cidr_block    = "10.254.0.0/28"
  create_service_account = true
  default_max_pods_per_node = 110

  ip_range_pods = var.ip_range_pods_name
  ip_range_services = var.ip_range_services_name
  network = module.gcp-network.network_name
  subnetwork = module.gcp-network.subnets_names[0]

  node_pools = var.node_pools

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/logging.write",
    ]
  }
}

// ----------------------------------------------------------------------------
// DNS configuration
// ----------------------------------------------------------------------------
resource "google_dns_record_set" "hostname" {
  project = var.project_id
  name = "${var.subdomain}.${data.google_dns_managed_zone.managed_zone.dns_name}"
  type = "A"
  ttl  = 300
  managed_zone = data.google_dns_managed_zone.managed_zone.name
  rrdatas = [google_compute_address.static.address]
}

data "google_dns_managed_zone" "managed_zone" {
  name = var.managed_zone_name
  project = var.project_id
}

// ----------------------------------------------------------------------------
// Static IP for ingress controller load balancer
// ----------------------------------------------------------------------------
resource "google_compute_address" "static" {
  provider = google-beta
  project = var.project_id
  name = "load-balancer-${var.cluster_name}"
  address_type = "EXTERNAL"
  region = var.region
  labels = {
    "owner": var.owner_label
  }
}
