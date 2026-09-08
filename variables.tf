variable "aws_region" {
  description = "AWS region in which resources will be created"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Name used when naming and tagging resources"
  type        = string
  default     = "auto-healing-web-tier"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type used by the web tier"
  type        = string
  default     = "t3.micro"
}