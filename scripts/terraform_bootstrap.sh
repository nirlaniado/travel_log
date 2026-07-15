#!/usr/bin/env bash
# One-time setup for infra/backend.tf's remote state: creates the DynamoDB
# lock table. The S3 bucket (s3-travellog-nirl10) already exists from
# scripts/create_s3_bucket.sh. Run this once, before the first
# `terraform -chdir=infra init`. Idempotent — safe to re-run.
set -euo pipefail

REGION="${AWS_REGION:-eu-north-1}"
TABLE="travellog-tf-lock"

if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "DynamoDB lock table '$TABLE' already exists in $REGION."
else
  echo "Creating DynamoDB lock table '$TABLE' in $REGION..."
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  aws dynamodb wait table-exists --table-name "$TABLE" --region "$REGION"
  echo "Lock table ready."
fi
