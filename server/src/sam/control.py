from copy import deepcopy
from datetime import timedelta
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import select

from .auth import aware
from .config import settings
from .models import Command, Confirmation, Link, now
from .store import emit


def node(scene, ident):
    found = next((n for n in scene.data["nodes"] if n["id"] == ident), None)
    if found is None:
        raise HTTPException(404, "NODE_NOT_FOUND")
    return found


def affected(scene, ident):
    ids = {ident}
    while True:
        added = {e["target"] for e in scene.data["edges"] if e["source"] in ids} - ids
        if not added:
            return sorted(ids)
        ids |= added


def recompute(scene):
    nodes = {n["id"]: n for n in scene.data["nodes"]}
    offline = {n["id"] for n in nodes.values() if not n["controls"]["power"]
               or not n["controls"]["connected"] or n["fault"] in ("OUTPUT_FAILURE", "SIGNAL_LOSS")}
    while True:
        propagated = {e["target"] for e in scene.data["edges"] if e["source"] in offline}
        new = propagated - offline
        if not new:
            break
        offline |= new
    for n in nodes.values():
        status = "OFFLINE" if n["id"] in offline else "DEGRADED" if n["fault"] else "ONLINE"
        if n["status"] != status:
            n["status"] = status
            n["version"] += 1
    active_conditions = {}
    for n in nodes.values():
        reason = n["fault"] or ("NODE_UNAVAILABLE" if n["status"] == "OFFLINE" else None)
        if reason:
            active_conditions[(n["id"], reason)] = n
    alerts = scene.data["alerts"]
    for alert in alerts:
        if alert["state"] != "RESOLVED" and (alert["node_id"], alert["condition"]) not in active_conditions:
            alert.update(state="RESOLVED", resolved_at=now().isoformat())
    for (ident, reason), n in active_conditions.items():
        if not any(a["node_id"] == ident and a["condition"] == reason and a["state"] != "RESOLVED" for a in alerts):
            alerts.append({"id": str(uuid4()), "node_id": ident, "condition": reason,
                           "severity": "CRITICAL" if reason == "OUTPUT_FAILURE" else "WARNING",
                           "state": "ACTIVE", "created_at": now().isoformat(),
                           "acknowledged_by": None, "resolved_at": None})
    scene.data = deepcopy(scene.data)


def changes(db, scene, before, category, message, ident=None, actor=None, correlation=None):
    old = {n["id"]: n for n in before["nodes"]}
    changed = [n for n in scene.data["nodes"] if n != old.get(n["id"])]
    emit(db, category, message, ident, actor, correlation,
         {"nodes": changed, "alerts": scene.data["alerts"], "generation": scene.generation,
          "paused": scene.paused, "tick": scene.tick})
    prior = {a["id"]: a for a in before["alerts"]}
    for a in scene.data["alerts"]:
        if a != prior.get(a["id"]):
            emit(db, "ALERT", f"{a['state']}: {a['condition']}", a["node_id"], actor, correlation,
                 {"alert": a})


def validate(db, scene, user, req):
    link = db.get(Link, req.link_id)
    if not link or link.user_id != user.id or link.node_id != req.node_id or link.revoked or link.generation != scene.generation:
        raise HTTPException(409, "LINK_REQUIRED")
    if aware(link.last_used) + timedelta(seconds=settings.link_idle_seconds) <= now():
        raise HTTPException(409, "LINK_EXPIRED")
    n = node(scene, req.node_id)
    if req.expected_version != n["version"]:
        raise HTTPException(409, "STALE_NODE_VERSION")
    if req.action not in n["capabilities"]:
        raise HTTPException(422, "UNSUPPORTED_CAPABILITY")
    # Own offline power/gateway controls remain available if upstream connectivity works.
    parents = [e["source"] for e in scene.data["edges"] if e["target"] == n["id"]]
    if any(node(scene, p)["status"] == "OFFLINE" for p in parents):
        raise HTTPException(409, "UPSTREAM_UNAVAILABLE")
    if n["status"] == "OFFLINE" and req.action not in ("power", "restart", "recover", "disconnect", "diagnostic"):
        raise HTTPException(409, "NODE_OFFLINE")
    if req.action in ("power", "disconnect") and type(req.value) is not bool:
        raise HTTPException(422, "BOOLEAN_REQUIRED")
    if req.action == "door" and req.value not in ("open", "closed"):
        raise HTTPException(422, "INVALID_DOOR_STATE")
    ranges = {"brightness": (0, 100), "pan": (-90, 90), "tilt": (-45, 45), "zoom": (1, 4)}
    if req.action in ranges:
        lo, hi = ranges[req.action]
        if type(req.value) not in (int, float) or not lo <= req.value <= hi:
            raise HTTPException(422, "VALUE_OUT_OF_RANGE")
    return n, link


def high_impact(req):
    return req.action in ("restart", "recover", "disconnect") or (req.action == "power" and req.value is False)


def fingerprint(req):
    return req.model_dump(exclude={"confirmation_id"})


def prepare(db, scene, user, req):
    n, link = validate(db, scene, user, req)
    ids = affected(scene, n["id"]) if high_impact(req) else [n["id"]]
    confirmation = Confirmation(id=str(uuid4()), user_id=user.id, link_id=link.id,
                                generation=scene.generation, request=fingerprint(req),
                                versions={i: node(scene, i)["version"] for i in ids},
                                expires_at=now() + timedelta(seconds=settings.confirmation_seconds), used=False)
    db.add(confirmation)
    link.last_used = now()
    return {"confirmation_id": confirmation.id, "expires_at": confirmation.expires_at.isoformat(),
            "affected_nodes": ids, "high_impact": high_impact(req)}


def execute(db, scene, user, req):
    existing = db.scalar(select(Command).where(Command.user_id == user.id, Command.key == req.key))
    if existing:
        if existing.request != fingerprint(req):
            raise HTTPException(409, "IDEMPOTENCY_KEY_REUSED")
        return existing.result
    n, link = validate(db, scene, user, req)
    if high_impact(req):
        confirmation = db.get(Confirmation, req.confirmation_id) if req.confirmation_id else None
        if not confirmation or confirmation.used or confirmation.user_id != user.id or confirmation.link_id != link.id or confirmation.generation != scene.generation or aware(confirmation.expires_at) <= now() or confirmation.request != fingerprint(req):
            raise HTTPException(409, "CONFIRMATION_REQUIRED")
        if any(node(scene, i)["version"] != v for i, v in confirmation.versions.items()):
            raise HTTPException(409, "IMPACT_CHANGED")
        confirmation.used = True
    before = deepcopy(scene.data)
    ident = str(uuid4())
    failed = n["fault"] == "OUTPUT_FAILURE" and req.action == "power" and req.value is True
    if not failed and req.action != "diagnostic":
        if req.action in ("restart", "recover"):
            n["fault"] = None
            n["controls"].update(power=True, connected=True)
            n["telemetry"]["uptime"] = 0
        elif req.action == "disconnect":
            n["controls"]["connected"] = not req.value
        else:
            n["controls"][req.action] = req.value
        n["version"] += 1
    n["last_command"] = ident
    link.last_used = now()
    recompute(scene)
    result = {"id": ident, "node_id": n["id"], "action": req.action,
              "state": "FAILED" if failed else "SUCCEEDED", "simulated": True,
              "error": "OUTPUT_FAILURE" if failed else None,
              "diagnostic": {"status": n["status"], "fault": n["fault"], "telemetry": n["telemetry"]} if req.action == "diagnostic" else None,
              "node": n}
    db.add(Command(id=ident, user_id=user.id, key=req.key, request=fingerprint(req), result=result))
    changes(db, scene, before, "COMMAND", f"{req.action.upper()} {result['state']}", n["id"], user.username, ident)
    return result
