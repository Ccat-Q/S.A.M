"""Test-only accounts; run exclusively against the ephemeral CI database."""
from uuid import uuid4
from sam.auth import passwords
from sam.models import User
from sam.store import transaction

with transaction() as db:
    for role in ("admin", "operator", "observer"):
        db.add(User(id=str(uuid4()), username=role, role=role, enabled=True,
                    password_hash=passwords.hash("Testing-Only-1234")))
