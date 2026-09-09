# The public image is a build artifact, shared by deployments of the web tier.
# This separate Terraform configuration manages its publishing repository.
terraform {
  required_version = ">= 1.12.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_ecrpublic_repository" "web" {
  repository_name = "auto-healing-web-tier"
  catalog_data {
    description       = "ARM64 NGINX welcome page for the auto-healing web tier assessment."
    architectures     = ["ARM 64"]
    operating_systems = ["Linux"]
  }
  tags = {
    Project   = "auto-healing-web-tier"
    ManagedBy = "Terraform"
  }
}

output "repository_url" {
  description = "Public dual-stack repository endpoint; use this for IPv6 VM pulls."
  value       = replace(aws_ecrpublic_repository.web.repository_uri, "public.ecr.aws/", "ecr-public.aws.com/")
}
