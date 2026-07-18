terraform {
  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "eticalhacking-s3-bucket" # El nombre que se definio en bootstrap
    key            = "infra/terraform.tfstate" # Nombre del archivo de estado
    region         = "us-east-1"
    dynamodb_table = "dynamodb-eticalhacking-locks" # La tabla que creaste
    encrypt        = true
  }
}

provider "aws" { 
    region = var.region 
}