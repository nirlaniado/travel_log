from datetime import UTC, datetime, timedelta

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .models import SessionRecord, User
from .security import hash_session_token

# last_seen_at is refreshed at most this often to avoid a write per request
LAST_SEEN_REFRESH = timedelta(minutes=5)


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def get_current_session(
    request: Request,
    db: Session = Depends(get_db),
) -> SessionRecord:
    settings = get_settings()
    token = request.cookies.get(settings.session_cookie_name)
    if not token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")

    record = db.execute(
        select(SessionRecord).where(SessionRecord.session_hash == hash_session_token(token))
    ).scalar_one_or_none()

    now = _utcnow()
    if record is None or record.revoked_at is not None or record.expires_at <= now:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired or invalid")

    if now - record.last_seen_at >= LAST_SEEN_REFRESH:
        record.last_seen_at = now
        db.commit()

    return record


def get_current_user(
    session_record: SessionRecord = Depends(get_current_session),
    db: Session = Depends(get_db),
) -> User:
    user = db.get(User, session_record.user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists")
    return user
