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
  region = var.region
}
