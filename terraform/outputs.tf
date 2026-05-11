output "firewall_policy_name" {
  description = "Created global network firewall policy name."
  value       = google_compute_network_firewall_policy.consumer.name
}

output "intercept_endpoint_group_id" {
  description = "Created intercept endpoint group resource ID."
  value       = google_network_security_intercept_endpoint_group.consumer.id
}

output "intercept_endpoint_group_association_id" {
  description = "Created intercept endpoint group association resource ID."
  value       = google_network_security_intercept_endpoint_group_association.consumer.id
}

output "security_profile_id" {
  description = "Created custom intercept security profile resource ID."
  value       = google_network_security_security_profile.custom_intercept.id
}

output "security_profile_group_id" {
  description = "Created security profile group resource ID."
  value       = google_network_security_security_profile_group.consumer.id
}
