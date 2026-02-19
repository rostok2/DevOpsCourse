locals {
  prefix = "rostok-imported-stack"
  az_pub = "eu-central-1a"
  az_pri = "eu-central-1b"
  ami_id = "ami-0d527370828225502" 
}

# 1. Створення VPC
module "network" {
  source      = "./vpc_module"
  vpc_cidr    = "10.10.0.0/16"
  name_prefix = local.prefix
}

# 2. Створення Підмереж
module "subnets" {
  source          = "./subnet_module"
  vpc_id          = module.network.vpc_id      # Використовуємо output з модуля network
  igw_id          = module.network.igw_id      # Використовуємо output з модуля network
  public_cidr     = "10.10.1.0/24"
  private_cidr    = "10.10.2.0/24"
  az_public       = local.az_pub
  az_private      = local.az_pri
  name_prefix     = local.prefix
}

# 3. Створення EC2 Інстансів
module "servers" {
  source              = "./ec2_module"
  ami_id              = local.ami_id
  public_subnet_id    = module.subnets.public_subnet_id   # Використовуємо output з модуля subnets
  private_subnet_id   = module.subnets.private_subnet_id  # Використовуємо output з модуля subnets
  name_prefix         = local.prefix
}