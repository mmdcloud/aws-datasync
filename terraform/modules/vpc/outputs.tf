output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnet_arns" {
  value = module.vpc.public_subnet_arns
}

output "private_subnet_arns" {
  value = module.vpc.private_subnet_arns
}