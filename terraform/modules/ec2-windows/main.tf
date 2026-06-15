variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "instance_name" {
  type    = string
  default = "SSM-Choco-Test"
}

data "aws_ssm_parameter" "windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

resource "aws_iam_role" "ssm_role" {
  name = "SSMWindowsRole-${var.instance_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSMWindowsProfile-${var.instance_name}"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "windows" {
  ami                  = data.aws_ssm_parameter.windows_ami.value
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name       = var.instance_name
    PatchGroup = "chocolatey"
  }
}

output "instance_id" {
  value = aws_instance.windows.id
}
