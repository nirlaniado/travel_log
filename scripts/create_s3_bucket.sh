#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

AWS_REGION="${AWS_REGION:-eu-north-1}"
S3_BUCKET="${S3_BUCKET:-}"

if [[ -z "$S3_BUCKET" ]]; then
  echo "Set S3_BUCKET to a globally unique bucket name, for example travelog-s3-your-company." >&2
  exit 1
fi

if [[ "$S3_BUCKET" == *"_"* ]]; then
  echo "S3 bucket names cannot contain underscores. Use a name like travelog-s3." >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required. Install it and configure AWS credentials first." >&2
  exit 1
fi

if aws s3api head-bucket --bucket "$S3_BUCKET" >/dev/null 2>&1; then
  echo "Bucket already exists: s3://$S3_BUCKET"
else
  if ! aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$AWS_REGION" \
    --create-bucket-configuration "LocationConstraint=$AWS_REGION"; then
    echo "Could not create s3://$S3_BUCKET. S3 bucket names are globally unique; choose another S3_BUCKET value." >&2
    exit 1
  fi
  aws s3api wait bucket-exists --bucket "$S3_BUCKET"
  echo "Created bucket: s3://$S3_BUCKET"
fi

aws s3api put-public-access-block \
  --bucket "$S3_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-versioning \
  --bucket "$S3_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$S3_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-bucket-ownership-controls \
  --bucket "$S3_BUCKET" \
  --ownership-controls \
  '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}'

echo "Configured s3://$S3_BUCKET in $AWS_REGION with versioning, encryption, ownership controls, and public access blocking."
