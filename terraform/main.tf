# Network
module "network" {
  source      = "./modules/network"
  name_prefix = "ssm-choco"
}

# Security Group
resource "aws_security_group" "ec2" {
  name_prefix = "ssm-choco-ec2-"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ssm-choco-ec2-sg" }
}

# EC2 Windows Instance (public subnet for Chocolatey internet access)
module "ec2" {
  source = "./modules/ec2-windows"

  subnet_id         = module.network.public_subnet_ids[0]
  security_group_id = aws_security_group.ec2.id
  instance_name     = "SSM-Choco-Test"
}

# Outputs
output "instance_id" {
  value = module.ec2.instance_id
}

output "vpc_id" {
  value = module.network.vpc_id
}
