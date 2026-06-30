variable "region" {
    type        = string
    description = "Región AWS donde serán desplegados los recursos"
    default     = "us-east-1"
}

terraform {
    required_version = ">= 1.2.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
        version = " ~> 5.0"
        }
    }

}

provider "aws" { region = var.region }