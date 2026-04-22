provider "aws" {
  region = "eu-west-2"
}
terraform {
  backend "s3" {
    bucket         = "mk-backend-bucket"
    key            = "spoke-1/terraform.tfstate"
    region         = "eu-west-2"
  }
}
