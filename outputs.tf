output "website_url" {
  description = "HTTPS endpoint balancing requests across both VMs."
  value       = module.web_tier.website_url
}
output "autoscaling_group_names" {
  description = "One replacement group for each fixed web slot."
  value       = module.web_tier.autoscaling_group_names
}
output "origin_dns_names" {
  description = "Stable AWS IPv6 origin hostnames; HTTP access is restricted to CloudFront."
  value       = module.web_tier.origin_dns_names
}
output "network_interface_ids" {
  description = "Persistent network interfaces reused by replacement VMs."
  value       = module.web_tier.network_interface_ids
}
output "vpc_id" {
  description = "VPC containing both web slots."
  value       = module.network.vpc_id
}
