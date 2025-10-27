module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name = "vpc"
  cidr = "10.0.0.0/16"
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true
  create_igw = true
  map_public_ip_on_launch = true
  enable_nat_gateway     = false
  single_nat_gateway     = false
  one_nat_gateway_per_az = false
  tags = var.tags
}