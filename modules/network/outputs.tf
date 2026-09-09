output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}
output "subnets" {
  description = "Subnet ID and AZ for each web slot."
  # Release subnet outputs to compute only after internet routing is ready.
  depends_on = [aws_route.internet_ipv6, aws_route_table_association.public]
  value = {
    for i, slot in ["a", "b"] : slot => {
      id                = aws_subnet.public[i].id
      availability_zone = aws_subnet.public[i].availability_zone
    }
  }
}
