from datetime import UTC, datetime, timedelta
from math import ceil

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..deps import get_current_session, get_current_user
from ..models import SessionRecord, User
from ..schemas import LoginRequest, MessageOut, RegisterRequest, UserOut
from ..security import (
    generate_session_token,
    hash_password,
    hash_session_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _create_session(db: Session, request: Request, response: Response, user: User) -> None:
    settings = get_settings()
    token = generate_session_token()
    now = _utcnow()
    expires_at = now + timedelta(hours=settings.session_lifetime_hours)

    db.add(
        SessionRecord(
            user_id=user.id,
            session_hash=hash_session_token(token),
            expires_at=expires_at,
            last_seen_at=now,
            user_agent=(request.headers.get("user-agent") or "")[:255] or None,
            ip_address=request.client.host if request.client else None,
        )
    )
    db.commit()

    response.set_cookie(
        key=settings.session_cookie_name,
        value=token,
        max_age=settings.session_lifetime_hours * 3600,
        httponly=True,
        secure=settings.cookie_secure,
        samesite="lax",
        path="/",
    )


def _locked_login_exception(locked_until: datetime, now: datetime) -> HTTPException:
    retry_after = max(1, ceil((locked_until - now).total_seconds()))
    return HTTPException(
        status.HTTP_429_TOO_MANY_REQUESTS,
        "Too many failed login attempts. Please wait and try again.",
        headers={"Retry-After": str(retry_after)},
    )


def _record_failed_login(db: Session, user: User | None, now: datetime) -> None:
    if user is None:
        return

    settings = get_settings()
    window_start = now - timedelta(minutes=settings.login_failure_window_minutes)
    if user.failed_login_first_at is None or user.failed_login_first_at < window_start:
        user.failed_login_first_at = now
        user.failed_login_count = 1
    else:
        user.failed_login_count += 1

    if user.failed_login_count >= settings.login_max_failed_attempts:
        user.locked_until = now + timedelta(minutes=settings.login_lockout_minutes)
        user.failed_login_count = 0
        user.failed_login_first_at = None

    db.commit()


def _clear_failed_login_state(user: User) -> None:
    user.failed_login_count = 0
    user.failed_login_first_at = None
    user.locked_until = None


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    existing = db.execute(select(User).where(User.username == payload.username)).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Username is already taken")

    user = User(username=payload.username, password_hash=hash_password(payload.password))
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Username is already taken") from None

    _create_session(db, request, response, user)
    return user


@router.post("/login", response_model=UserOut)
def login(
    payload: LoginRequest,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    user = db.execute(select(User).where(User.username == payload.username).with_for_update()).scalar_one_or_none()
    now = _utcnow()
    if user is not None and user.locked_until is not None:
        if user.locked_until > now:
            raise _locked_login_exception(user.locked_until, now)
        _clear_failed_login_state(user)

    # Same error for unknown user and wrong password: no username enumeration.
    if user is None or not verify_password(payload.password, user.password_hash):
        _record_failed_login(db, user, now)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid username or password")

    _clear_failed_login_state(user)
    _create_session(db, request, response, user)
    return user


@router.post("/logout", response_model=MessageOut)
def logout(
    response: Response,
    session_record: SessionRecord = Depends(get_current_session),
    db: Session = Depends(get_db),
):
    session_record.revoked_at = _utcnow()
    db.commit()

    settings = get_settings()
    response.delete_cookie(
        key=settings.session_cookie_name,
        httponly=True,
        secure=settings.cookie_secure,
        samesite="lax",
        path="/",
    )
    return {"message": "Logged out"}


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user
