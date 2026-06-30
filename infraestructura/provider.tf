terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = " ~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "eticalhacking-s3-bucket"
    key            = "global/s3/terraform.tfstate"                
    region         = "us-east-1"
    use_lockfile   = true                     
    encrypt        = true
  }

}

provider "aws" { region = var.region }