provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "travel-log"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
