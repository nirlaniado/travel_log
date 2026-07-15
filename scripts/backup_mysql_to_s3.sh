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
S3_PREFIX="${S3_PREFIX:-mysql}"

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-travel_log}"
MYSQL_USER="${MYSQL_USER:-travel}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-travel}"

BACKUP_DIR="${BACKUP_DIR:-/tmp/travel_log_backups}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_BASENAME="${MYSQL_DATABASE}_${TIMESTAMP}.sql.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_BASENAME"
CHECKSUM_PATH="$BACKUP_PATH.sha256"
S3_KEY="$S3_PREFIX/$(date -u +%Y/%m/%d)/$BACKUP_BASENAME"

if [[ "$S3_BUCKET" == *"_"* ]]; then
  echo "S3 bucket names cannot contain underscores. Use a name like travelog-s3." >&2
  exit 1
fi

if [[ -z "$S3_BUCKET" ]]; then
  echo "Set S3_BUCKET to the backup bucket name." >&2
  exit 1
fi

for required_command in aws gzip sha256sum; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "$required_command is required but was not found in PATH." >&2
    exit 1
  fi
done

MYSQLDUMP_MODE=""
if command -v mysqldump >/dev/null 2>&1; then
  MYSQLDUMP_MODE="host"
elif command -v docker >/dev/null 2>&1 && docker compose ps -q db >/dev/null 2>&1; then
  MYSQLDUMP_MODE="docker"
else
  echo "mysqldump was not found on the host, and the Docker Compose db service is not available." >&2
  echo "Start the stack with 'docker compose up -d db' or install a MySQL client locally." >&2
  exit 1
fi

run_mysqldump() {
  if [[ "$MYSQLDUMP_MODE" == "host" ]]; then
    MYSQL_PWD="$MYSQL_PASSWORD" mysqldump \
      --host="$MYSQL_HOST" \
      --port="$MYSQL_PORT" \
      --user="$MYSQL_USER" \
      --single-transaction \
      --no-tablespaces \
      --routines \
      --triggers \
      --events \
      "$MYSQL_DATABASE"
  else
    docker compose exec -T -e MYSQL_PWD="$MYSQL_PASSWORD" db mysqldump \
      --host=127.0.0.1 \
      --port=3306 \
      --user="$MYSQL_USER" \
      --single-transaction \
      --no-tablespaces \
      --routines \
      --triggers \
      --events \
      "$MYSQL_DATABASE"
  fi
}

mkdir -p "$BACKUP_DIR"
umask 077

echo "Creating MySQL backup for database '$MYSQL_DATABASE' using $MYSQLDUMP_MODE mysqldump..."
run_mysqldump | gzip -c > "$BACKUP_PATH"

sha256sum "$BACKUP_PATH" > "$CHECKSUM_PATH"

echo "Uploading backup to s3://$S3_BUCKET/$S3_KEY..."
aws s3 cp "$BACKUP_PATH" "s3://$S3_BUCKET/$S3_KEY" \
  --region "$AWS_REGION" \
  --sse AES256

aws s3 cp "$CHECKSUM_PATH" "s3://$S3_BUCKET/$S3_KEY.sha256" \
  --region "$AWS_REGION" \
  --sse AES256

echo "Backup uploaded:"
echo "  s3://$S3_BUCKET/$S3_KEY"
echo "  s3://$S3_BUCKET/$S3_KEY.sha256"
