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