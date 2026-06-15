terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "REPLACE_WITH_YOUR_TFC_ORG"
    workspaces {
      name = "ssm-chocolatey-patching"
    }
  }
}

provider "aws" {
  alias  = "management"
  region = var.region
}

provider "aws" {
  alias  = "target_account_a"
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.target_account_a_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "target_account_b"
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.target_account_b_id}:role/OrganizationAccountAccessRole"
  }
}
