variable "aws_region" {
  description = "Region used by the cost estimate and pinned ARM64 AMI."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "This costed configuration and pinned AMI target us-east-1."
  }
  validation {
    condition     = var.aws_region != "" && terraform.workspace == "budget-constraint"
    error_message = "Use the isolated budget workspace: terraform workspace select -or-create budget-constraint. The default workspace may contain the previous Sydney deployment."
  }
}
variable "project_name" {
  description = "Short project prefix for names and tags."
  type        = string
  default     = "auto-healing-web-tier"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,27}$", var.project_name))
    error_message = "Use 3-28 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "environment" {
  description = "Environment used in names and tags."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
variable "ami_id" {
  description = "Pinned AL2023 minimal ARM64 AMI in us-east-1, verified 2026-09-09."
  type        = string
  default     = "ami-00d2032fba650e58b"
  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "Provide an ARM64 AMI ID in us-east-1."
  }
}
variable "container_image" {
  description = "Public ARM64 NGINX image pinned by digest, using ECR Public's dual-stack endpoint."
  type        = string
  default     = "ecr-public.aws.com/n0l2m0r6/auto-healing-web-tier@sha256:bb72fe04472b22fb7e4f8026aded48d9e5a80b4e73e488626032b3fec0181a4b"
  validation {
    condition     = can(regex("^ecr-public\\.aws\\.com/[a-z0-9][a-z0-9./_-]*@sha256:[0-9a-f]{64}$", var.container_image))
    error_message = "Use an ecr-public.aws.com image URL pinned with @sha256:<64 hex characters>."
  }
}
variable "vpc_cidr" {
  description = "Private IPv4 range. Internet connectivity uses IPv6."
  type        = string
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  description = "Exactly two private IPv4 ranges for dual-stack web subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Provide exactly two subnet CIDRs, one per web slot."
  }
}
