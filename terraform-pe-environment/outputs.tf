# output "pe_instance_public_ip" {
#   description = "PE ip"
#   value       = google_compute_instance.pe.network_interface.0.access_config.0.nat_ip
# }

# output "node1_instance_public_ip" {
#   description = "node1 ip"
#   value       = google_compute_instance.node1.network_interface.0.access_config.0.nat_ip
# }