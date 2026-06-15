# Network - Account A
module "network_account_a" {
  source = "./modules/network"
  providers = {
    aws = aws.target_account_a
  }
  name_prefix = "ssm-choco-a"
}

# Network - Account B
module "network_account_b" {
  source = "./modules/network"
  providers = {
    aws = aws.target_account_b
  }
  name_prefix = "ssm-choco-b"
}

# Security Group - Account A
resource "aws_security_group" "ec2_account_a" {
  provider    = aws.target_account_a
  name_prefix = "ssm-choco-ec2-"
  vpc_id      = module.network_account_a.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ssm-choco-ec2-sg-a" }
}

# Security Group - Account B
resource "aws_security_group" "ec2_account_b" {
  provider    = aws.target_account_b
  name_prefix = "ssm-choco-ec2-"
  vpc_id      = module.network_account_b.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ssm-choco-ec2-sg-b" }
}

# EC2 - Account A (public subnet for Chocolatey internet access)
module "ec2_account_a" {
  source = "./modules/ec2-windows"
  providers = {
    aws = aws.target_account_a
  }

  subnet_id         = module.network_account_a.public_subnet_ids[0]
  security_group_id = aws_security_group.ec2_account_a.id
  instance_name     = "SSM-Choco-Test-AccountA"
}

# EC2 - Account B (public subnet for Chocolatey internet access)
module "ec2_account_b" {
  source = "./modules/ec2-windows"
  providers = {
    aws = aws.target_account_b
  }

  subnet_id         = module.network_account_b.public_subnet_ids[0]
  security_group_id = aws_security_group.ec2_account_b.id
  instance_name     = "SSM-Choco-Test-AccountB"
}

# Outputs
output "instance_id_account_a" {
  value = module.ec2_account_a.instance_id
}

output "instance_id_account_b" {
  value = module.ec2_account_b.instance_id
}

output "vpc_id_account_a" {
  value = module.network_account_a.vpc_id
}

output "vpc_id_account_b" {
  value = module.network_account_b.vpc_id
}
