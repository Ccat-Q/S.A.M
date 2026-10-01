from copy import deepcopy
from contextlib import contextmanager
from datetime import datetime, timedelta

from sqlalchemy import create_engine, delete, func, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm.attributes import flag_modified

from .config import settings
from .models import Command, Confirmation, Event, Link, Scan, Scene, Session, now
from .seed import initial_scene

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionFactory = sessionmaker(engine, expire_on_commit=False)


@contextmanager
def transaction():
    with SessionFactory.begin() as db:
        yield db


def locked_scene(db):
    scene = db.scalar(select(Scene).where(Scene.id == 1).with_for_update())
    if scene is None:
        scene = Scene(id=1, generation=1, tick=0, paused=False, data=initial_scene())
        db.add(scene)
        db.flush()
    scene.data = deepcopy(scene.data)
    return scene


def event_dict(e):
    return {"cursor": e.id, "time": e.created_at.isoformat(), "category": e.category,
            "message": e.message, "node_id": e.node_id, "actor": e.actor,
            "correlation_id": e.correlation_id, "data": e.data}


def emit(db, category, message, node_id=None, actor=None, correlation_id=None, data=None):
    event = Event(category=category, message=message, node_id=node_id, actor=actor,
                  correlation_id=correlation_id, data=data or {})
    db.add(event)
    db.flush()
    return event


def snapshot(db):
    scene = db.scalar(select(Scene).where(Scene.id == 1).with_for_update(read=True))
    # Writers lock the same row until their state AND event are committed.
    if scene is None:
        scene = locked_scene(db)
    cursor = db.scalar(select(func.max(Event.id))) or 0
    return {**deepcopy(scene.data), "generation": scene.generation, "tick": scene.tick,
            "paused": scene.paused, "cursor": cursor, "server_time": now().isoformat(),
            "simulated": True}


def purge(db):
    at = now()
    scene = locked_scene(db)
    cutoff = at - timedelta(days=settings.audit_retention_days)
    scene.data["alerts"] = [a for a in scene.data["alerts"] if a["state"] != "RESOLVED"
                            or datetime.fromisoformat(a["resolved_at"]) >= cutoff]
    scene.data = deepcopy(scene.data)
    flag_modified(scene, "data")
    db.execute(delete(Event).where(Event.created_at < at - timedelta(days=settings.audit_retention_days)))
    db.execute(delete(Event).where(Event.category.not_in(["USER", "SECURITY", "COMMAND", "ALERT"]),
                                  Event.created_at < at - timedelta(days=settings.log_retention_days)))
    db.execute(delete(Command).where(Command.created_at < at - timedelta(days=settings.audit_retention_days)))
    db.execute(delete(Session).where(Session.expires_at < at))
    db.execute(delete(Confirmation).where(Confirmation.expires_at < at))
    db.execute(delete(Scan).where(Scan.expires_at < at))
    db.execute(delete(Link).where(Link.last_used < at - timedelta(seconds=settings.link_idle_seconds)))
