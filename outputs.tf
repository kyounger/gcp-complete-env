
output "static_ip" {
  description = "Static IP created and associated with host record"
  value       = module.address-fe.addresses[0]
}

output "fqdn" {
  description = "Fully qualified hostname with domain name"
  value       = trimsuffix(google_dns_record_set.hostname.name,".")
}

output "static_ip_map" {
  description = "mapping of static IPs meant to be attached the ingress controller for particular cluster"
  value =  [for x in module.gke-clusters : {
    cluster_name = x.cluster_name
    static_ip = x.static_ip
  }]
}

output "secondary_ranges" {
  value = local.secondary_ranges
}