variable "project_name" {
  description = "Project prefix for resource names."
  type        = string
}
variable "environment" {
  description = "Environment for names and tags."
  type        = string
}
variable "ami_id" {
  description = "Pinned regional AL2023 ARM64 AMI."
  type        = string
}
variable "vpc_id" {
  description = "VPC containing the web slots."
  type        = string
}
variable "subnets" {
  description = "Exactly two web slots in distinct AZs."
  type = map(object({
    id                = string
    availability_zone = string
  }))
  validation {
    condition     = toset(keys(var.subnets)) == toset(["a", "b"]) && length(distinct([for s in values(var.subnets) : s.availability_zone])) == 2
    error_message = "Supply slots a and b in two different Availability Zones."
  }
}
