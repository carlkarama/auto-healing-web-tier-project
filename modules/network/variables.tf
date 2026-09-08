variable "project_name" {
  description = "Name used when naming network resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to the public subnets"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDR blocks must be provided."
  }
}

variable "availability_zones" {
  description = "Availability Zones used by the public subnets"
  type        = list(string)
}