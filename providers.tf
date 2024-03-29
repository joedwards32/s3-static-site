terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Configure aws provider
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

provider "aws" {
  alias = "us-east-1"
  region  = "us-east-1"
}

