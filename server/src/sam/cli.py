import argparse
import getpass
from uuid import uuid4

from sqlalchemy import select

from .auth import passwords
from .models import User
from .store import emit, locked_scene, transaction


def main():
    parser = argparse.ArgumentParser(description="Initialize S.A.M. administrator (no default password)")
    parser.add_argument("username")
    args = parser.parse_args()
    password = getpass.getpass("Password (12+ characters): ")
    if len(password) < 12 or len(password) > 128:
        parser.error("Password must be 12–128 characters")
    if password != getpass.getpass("Repeat password: "):
        parser.error("Passwords do not match")
    with transaction() as db:
        locked_scene(db)
        if db.scalar(select(User).where(User.username == args.username)):
            parser.error("Member already exists; no password changed")
        db.add(User(id=str(uuid4()), username=args.username, password_hash=passwords.hash(password),
                    role="admin", enabled=True))
        emit(db, "SECURITY", f"ADMIN INITIALIZED: {args.username}", actor="CLI")
    print("Administrator created")
