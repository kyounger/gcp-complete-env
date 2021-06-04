
data "google_client_config" "default" {}

#------- kubernetes stuff ---------#

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
  master_ipv4_cidr_block    = var.master_ipv4_cidr_block
  create_service_account = true
  default_max_pods_per_node = 110

  ip_range_pods = var.ip_range_pods_name
  ip_range_services = var.ip_range_services_name
  network = var.global_network_name
  subnetwork = var.subnetwork_name

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

