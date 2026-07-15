#!/usr/bin/env sh
set -eu

python - <<'PY'
import time

from app.config import get_settings
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

database_url = get_settings().database_url
deadline = time.monotonic() + 60

while True:
    try:
        engine = create_engine(database_url, pool_pre_ping=True)
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        break
    except OperationalError as exc:
        if time.monotonic() >= deadline:
            raise exc
        print("Waiting for MySQL to accept connections...")
        time.sleep(2)
PY

alembic upgrade head
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
