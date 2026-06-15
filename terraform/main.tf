module "ec2_account_a" {
  source = "./modules/ec2-windows"
  providers = {
    aws = aws.target_account_a
  }

  subnet_id         = var.subnet_id_account_a
  security_group_id = var.security_group_id_account_a
  instance_name     = "SSM-Choco-Test-AccountA"
}

module "ec2_account_b" {
  source = "./modules/ec2-windows"
  providers = {
    aws = aws.target_account_b
  }

  subnet_id         = var.subnet_id_account_b
  security_group_id = var.security_group_id_account_b
  instance_name     = "SSM-Choco-Test-AccountB"
}

output "instance_id_account_a" {
  value = module.ec2_account_a.instance_id
}

output "instance_id_account_b" {
  value = module.ec2_account_b.instance_id
}
