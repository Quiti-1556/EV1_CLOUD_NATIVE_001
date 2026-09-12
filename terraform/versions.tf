terraform {
  required_version = ">= 1.11.0, < 2.0"
  backend "s3" {}
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.100" }
    archive = { source = "hashicorp/archive", version = "~> 2.7" }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" }
  }
}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  name           = "${var.project}-${var.environment}"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  frontend_url   = "https://${var.frontend_branch}.${aws_amplify_app.front.default_domain}"
  issuer         = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.users.id}"
  cognito_domain = "https://${aws_cognito_user_pool_domain.login.domain}.auth.${var.aws_region}.amazoncognito.com"
  origins        = concat([local.frontend_url], var.local_development ? ["http://localhost:4200"] : [])
}
