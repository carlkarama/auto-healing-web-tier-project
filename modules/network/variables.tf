variable "project_name" {
  description = "Project name prefix."
  type        = string
}
variable "environment" {
  description = "Environment name."
  type        = string
}
variable "vpc_cidr" {
  description = "VPC private IPv4 range."
  type        = string
}
variable "public_subnet_cidrs" {
  description = "Two private IPv4 ranges for dual-stack subnets."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Two subnet CIDRs are required."
  }
}
variable "availability_zones" {
  description = "Two distinct AZs."
  type        = list(string)
  validation {
    condition     = length(distinct(var.availability_zones)) == 2
    error_message = "Two distinct Availability Zones are required."
  }
}
