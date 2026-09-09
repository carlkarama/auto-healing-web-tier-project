output "website_url" {
  description = "CloudFront HTTPS endpoint."
  value       = "https://${aws_cloudfront_distribution.web.domain_name}"
}
output "autoscaling_group_names" {
  description = "Replacement group names keyed by slot."
  value       = { for slot, group in aws_autoscaling_group.web : slot => group.name }
}
output "origin_dns_names" {
  description = "Stable public IPv6 origin hostnames."
  value       = { for slot, eni in awscc_ec2_network_interface.web : slot => eni.public_ip_dns_name_options.public_ipv_6_dns_name }
}
output "network_interface_ids" {
  description = "Persistent ENIs keyed by slot."
  value       = { for slot, eni in awscc_ec2_network_interface.web : slot => eni.id }
}
