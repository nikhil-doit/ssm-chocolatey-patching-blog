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

# SSM Chocolatey - Package Management
module "ssm_chocolatey" {
  source = "./modules/ssm-chocolatey"

  packages = [
    { Name = "7zip", Version = "latest", Upgrade = "yes", Switches = "" },
    { Name = "notepadplusplus", Version = "latest", Upgrade = "yes", Switches = "" },
    { Name = "googlechrome", Version = "latest", Upgrade = "yes", Switches = "" },
    { Name = "firefox", Version = "latest", Upgrade = "yes", Switches = "" },
    { Name = "vim", Version = "latest", Upgrade = "yes", Switches = "" },
  ]

  association_schedule = "rate(1 day)"
  target_tag_key       = "PatchGroup"
  target_tag_value     = "chocolatey"
}

# Outputs
output "instance_id" {
  value = module.ec2.instance_id
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "ssm_document_name" {
  value = module.ssm_chocolatey.document_name
}

output "ssm_association_id" {
  value = module.ssm_chocolatey.association_id
}
