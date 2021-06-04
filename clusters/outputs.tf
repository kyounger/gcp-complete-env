
output "static_ip" {
  description = "Static IP created and associated with host record"
  value       = google_compute_address.static.address
}

output "cluster_name" {
  value = module.gke.name
}