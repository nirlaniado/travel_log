# Remote state — reuses the S3 bucket already created for MySQL backups
# (scripts/create_s3_bucket.sh), under its own key prefix, with a DynamoDB
# lock table. Run scripts/terraform_bootstrap.sh once before the first
# `terraform init` to create the lock table (the bucket already exists).
terraform {
  backend "s3" {
    bucket         = "s3-travellog-nirl10"
    key            = "terraform/travel-log.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "travellog-tf-lock"
    encrypt        = true
  }
}
