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
variable "container_image" {
  description = "Public ARM64 NGINX image pinned by digest, using ECR Public's dual-stack endpoint."
  type        = string
  validation {
    condition     = can(regex("^ecr-public\\.aws\\.com/[a-z0-9][a-z0-9./_-]*@sha256:[0-9a-f]{64}$", var.container_image))
    error_message = "Use an ecr-public.aws.com image URL pinned with @sha256:<64 hex characters>."
  }
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
