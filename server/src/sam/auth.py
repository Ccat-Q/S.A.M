import hashlib
import secrets
from datetime import timedelta

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy import select

from .config import settings
from .models import Session, User, now
from .store import SessionFactory

passwords = PasswordHash.recommended()
bearer = HTTPBearer(auto_error=False)
dummy_hash = passwords.hash("constant-time-non-member-password")


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


def aware(value):
    return value if value.tzinfo else value.replace(tzinfo=now().tzinfo)


def user_for_token(token):
    with SessionFactory() as db:
        session = db.get(Session, token_hash(token))
        user = db.get(User, session.user_id) if session else None
        if not session or aware(session.expires_at) <= now() or not user or not user.enabled:
            raise HTTPException(401, "SESSION_EXPIRED")
        user.auth_session_hash = session.token_hash
        return user


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if not credentials:
        raise HTTPException(401, "AUTH_REQUIRED")
    return user_for_token(credentials.credentials)


def require_operator(user=Depends(current_user)):
    if user.role not in ("admin", "operator"):
        raise HTTPException(403, "CONTROL_FORBIDDEN")
    return user


def require_admin(user=Depends(current_user)):
    if user.role != "admin":
        raise HTTPException(403, "ADMIN_REQUIRED")
    return user


def issue_session(db, user):
    token = secrets.token_urlsafe(48)
    expiry = now() + timedelta(seconds=settings.session_seconds)
    db.add(Session(token_hash=token_hash(token), user_id=user.id, expires_at=expiry))
    return {"token": token, "expires_at": expiry.isoformat(),
            "user": member_dict(user)}


def member_dict(user):
    return {"id": user.id, "username": user.username, "role": user.role, "enabled": user.enabled}


def authenticate(db, username, password):
    user = db.scalar(select(User).where(User.username == username))
    valid = passwords.verify(password, user.password_hash if user else dummy_hash)
    if not user or not valid or not user.enabled:
        raise HTTPException(401, "INVALID_CREDENTIALS")
    return user
