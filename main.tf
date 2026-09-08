data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "./modules/network"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "web_tier" {
  source = "./modules/web-tier"

  project_name      = var.project_name
  environment       = var.environment
  instance_type     = var.instance_type
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}