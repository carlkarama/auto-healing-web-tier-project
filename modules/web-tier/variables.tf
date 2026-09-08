variable "project_name" {
  description = "Name used when naming web-tier resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC containing the web tier"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets used by the load balancer"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnet IDs must be provided."
  }
}

variable "instance_type" {
  description = "EC2 instance type used by the web tier"
  type        = string
}

variable "min_size" {
  description = "Minimum number of web instances"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of web instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of web instances"
  type        = number
}