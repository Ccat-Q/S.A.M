from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from sam.api import app, login_attempts
from sam.auth import passwords
from sam.models import Base, User
from sam.store import engine, transaction


@pytest.fixture
def client():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    login_attempts.clear()
    with transaction() as db:
        for role in ("admin", "operator", "observer"):
            db.add(User(id=str(uuid4()), username=role, password_hash=passwords.hash("Testing-Only-1234"),
                        role=role, enabled=True))
    with TestClient(app) as client:
        yield client


def login(client, username="admin"):
    result = client.post("/api/auth/login", json={"username": username, "password": "Testing-Only-1234"})
    assert result.status_code == 200
    return {"Authorization": "Bearer " + result.json()["token"]}


@pytest.fixture
def admin(client):
    return login(client)
