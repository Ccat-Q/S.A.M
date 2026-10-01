import asyncio
import contextlib
import logging
import time
from collections import OrderedDict, deque
from contextlib import asynccontextmanager
from copy import deepcopy
from datetime import timedelta
from threading import Lock
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, Query, Request, WebSocket, WebSocketDisconnect
from sqlalchemy import delete, func, or_, select
from sqlalchemy.exc import IntegrityError

from . import simulator
from .auth import (authenticate, aware, current_user, issue_session, member_dict, passwords,
                   require_admin, require_operator, token_hash, user_for_token)
from .config import settings
from .control import changes, execute, node, prepare, recompute
from .models import Command, Confirmation, Event, Link, Scan, Scene, Session, User, now
from .schemas import (CommandRequest, FaultRequest, LinkRequest, LoginRequest,
                      MemberCreate, MemberUpdate, SimulationRequest)
from .seed import initial_scene
from .store import SessionFactory, emit, event_dict, locked_scene, snapshot, transaction

logger = logging.getLogger(__name__)
login_attempts = OrderedDict()
login_lock = Lock()


@asynccontextmanager
async def lifespan(app):
    with transaction() as db:
        scene = locked_scene(db)
        # Process restarts never preserve control grants or confirmation tokens.
        db.execute(delete(Link))
        db.execute(delete(Confirmation))
        emit(db, "SYSTEM", "CORE INITIALIZED", data={"generation": scene.generation})
    task = asyncio.create_task(simulator.run()) if settings.simulation_enabled else None
    yield
    if task:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


app = FastAPI(title="S.A.M. Control API", version="0.1.0", lifespan=lifespan)


@app.middleware("http")
async def no_cache(request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.get("/health")
def health():
    with SessionFactory() as db:
        db.execute(select(Scene.id).limit(1))
    return {"status": "ONLINE", "simulated": True}


def authorized_scene(db, user, admin=False):
    scene = locked_scene(db)
    current = db.get(User, user.id)
    session = db.get(Session, user.auth_session_hash)
    if not current or not current.enabled or not session or aware(session.expires_at) <= now():
        raise HTTPException(401, "SESSION_EXPIRED")
    allowed = ("admin",) if admin else ("admin", "operator")
    if current.role not in allowed:
        raise HTTPException(403, "ADMIN_REQUIRED" if admin else "CONTROL_FORBIDDEN")
    return scene


@app.post("/api/auth/login")
def login(body: LoginRequest, request: Request):
    # Do not trust X-Forwarded-For; cloudflared is the sole published entrance.
    key = body.username.lower()
    at = time.monotonic()
    with login_lock:
        if key not in login_attempts:
            if len(login_attempts) >= 2048:
                login_attempts.popitem(last=False)
            login_attempts[key] = deque()
        attempts = login_attempts[key]
        login_attempts.move_to_end(key)
        while attempts and attempts[0] < at - 60:
            attempts.popleft()
        if len(attempts) >= 10:
            raise HTTPException(429, "LOGIN_RATE_LIMIT")
        attempts.append(at)
    with transaction() as db:
        user = authenticate(db, body.username, body.password)
        result = issue_session(db, user)
        emit(db, "SECURITY", "MEMBER AUTHENTICATED", actor=user.username)
    return result


@app.get("/api/auth/me")
def me(user=Depends(current_user)):
    return member_dict(user)


@app.post("/api/auth/logout")
def logout(request: Request, user=Depends(current_user)):
    token = request.headers["authorization"].split(" ", 1)[1]
    with transaction() as db:
        db.execute(delete(Session).where(Session.token_hash == token_hash(token)))
        for link in db.scalars(select(Link).where(Link.session_hash == token_hash(token))):
            link.revoked = True
        emit(db, "SECURITY", "MEMBER DISCONNECTED", actor=user.username)
    return {"ok": True}


@app.get("/api/snapshot")
def get_snapshot(user=Depends(current_user)):
    with transaction() as db:
        return snapshot(db)


@app.get("/api/nodes/{ident}")
def inspect_node(ident: str, user=Depends(current_user)):
    with SessionFactory() as db:
        scene = db.get(Scene, 1)
        return {"state": "IDENTIFIED", "node": node(scene, ident), "generation": scene.generation,
                "can_control": user.role in ("admin", "operator")}


@app.post("/api/nodes/{ident}/scan")
def scan(ident: str, request: Request, user=Depends(current_user)):
    with transaction() as db:
        scene = locked_scene(db)
        n = node(scene, ident)
        receipt = Scan(id=str(uuid4()), user_id=user.id, node_id=ident,
                       session_hash=token_hash(request.headers["authorization"].split(" ", 1)[1]),
                       generation=scene.generation,
                       expires_at=now() + timedelta(seconds=settings.link_idle_seconds))
        db.add(receipt)
        emit(db, "CAMERA" if n["type"] == "CAMERA" else "DEVICE", "NODE IDENTIFIED", ident, user.username)
        return {"state": "IDENTIFIED", "scan_id": receipt.id, "node": n,
                "generation": scene.generation, "can_control": user.role in ("admin", "operator")}


@app.post("/api/links")
def create_link(body: LinkRequest, request: Request, user=Depends(require_operator)):
    with transaction() as db:
        scene = authorized_scene(db, user)
        n = node(scene, body.node_id)
        if scene.generation != body.generation:
            raise HTTPException(409, "SCENE_CHANGED")
        parents = [e["source"] for e in scene.data["edges"] if e["target"] == n["id"]]
        if any(node(scene, p)["status"] == "OFFLINE" for p in parents):
            raise HTTPException(409, "UPSTREAM_UNAVAILABLE")
        session_hash = token_hash(request.headers["authorization"].split(" ", 1)[1])
        receipt = db.get(Scan, body.scan_id)
        if not receipt or receipt.user_id != user.id or receipt.session_hash != session_hash or receipt.node_id != n["id"] or receipt.generation != scene.generation or aware(receipt.expires_at) <= now():
            raise HTTPException(409, "SCAN_REQUIRED")
        link = Link(id=str(uuid4()), user_id=user.id, session_hash=session_hash, node_id=n["id"], generation=scene.generation,
                    last_used=now(), revoked=False)
        db.add(link)
        emit(db, "USER", "CONTROL LINK ESTABLISHED", n["id"], user.username)
        return {"id": link.id, "node_id": link.node_id, "state": "ESTABLISHED",
                "idle_seconds": settings.link_idle_seconds, "generation": scene.generation}


@app.delete("/api/links/{ident}")
def revoke_link(ident: str, user=Depends(current_user)):
    with transaction() as db:
        link = db.get(Link, ident)
        if link and link.user_id == user.id:
            link.revoked = True
    return {"ok": True}


@app.post("/api/commands/prepare")
def prepare_command(body: CommandRequest, user=Depends(require_operator)):
    with transaction() as db:
        return prepare(db, authorized_scene(db, user), user, body)


@app.post("/api/commands")
def command(body: CommandRequest, user=Depends(require_operator)):
    with transaction() as db:
        return execute(db, authorized_scene(db, user), user, body)


@app.get("/api/commands/by-key/{key}")
def command_result(key: str, user=Depends(current_user)):
    with SessionFactory() as db:
        c = db.scalar(select(Command).where(Command.user_id == user.id, Command.key == key))
        if c is None:
            raise HTTPException(404, "COMMAND_NOT_FOUND")
        return c.result


@app.post("/api/alerts/{ident}/acknowledge")
def acknowledge(ident: str, user=Depends(require_operator)):
    with transaction() as db:
        scene = authorized_scene(db, user)
        before = deepcopy(scene.data)
        a = next((a for a in scene.data["alerts"] if a["id"] == ident), None)
        if a is None:
            raise HTTPException(404, "ALERT_NOT_FOUND")
        if a["state"] == "ACTIVE":
            a.update(state="ACKNOWLEDGED", acknowledged_by=user.username)
            scene.data = deepcopy(scene.data)
            changes(db, scene, before, "USER", "ALERT ACKNOWLEDGED", a["node_id"], user.username)
        return a


@app.get("/api/logs")
def logs(q: str = "", category: str = "", node_id: str = "", before: int | None = None,
         since: str | None = None, until: str | None = None,
         limit: int = Query(100, ge=1, le=500), user=Depends(current_user)):
    from datetime import datetime
    with SessionFactory() as db:
        query = select(Event).order_by(Event.id.desc()).limit(limit)
        if category:
            query = query.where(Event.category == category)
        else:
            query = query.where(Event.category != "TELEMETRY")
        if node_id:
            query = query.where(Event.node_id == node_id)
        if q:
            query = query.where(or_(Event.message.ilike(f"%{q}%"), Event.actor.ilike(f"%{q}%")))
        if before is not None:
            query = query.where(Event.id < before)
        for value, lower in ((since, True), (until, False)):
            if value:
                try:
                    date = datetime.fromisoformat(value)
                    if date.tzinfo is None:
                        raise ValueError()
                except ValueError:
                    raise HTTPException(422, "TIMEZONE_REQUIRED") from None
                query = query.where(Event.created_at >= date if lower else Event.created_at <= date)
        return [event_dict(e) for e in db.scalars(query)]


@app.get("/api/members")
def members(user=Depends(require_admin)):
    with SessionFactory() as db:
        return [member_dict(u) for u in db.scalars(select(User).order_by(User.username))]


@app.post("/api/members", status_code=201)
def create_member(body: MemberCreate, user=Depends(require_admin)):
    try:
        with transaction() as db:
            authorized_scene(db, user, admin=True)
            member = User(id=str(uuid4()), username=body.username, password_hash=passwords.hash(body.password),
                          role=body.role, enabled=True)
            db.add(member)
            emit(db, "SECURITY", f"MEMBER CREATED: {body.username} / {body.role}", actor=user.username)
            return member_dict(member)
    except IntegrityError:
        raise HTTPException(409, "USERNAME_EXISTS") from None


@app.patch("/api/members/{ident}")
def update_member(ident: str, body: MemberUpdate, user=Depends(require_admin)):
    with transaction() as db:
        authorized_scene(db, user, admin=True)
        member = db.get(User, ident)
        if not member:
            raise HTTPException(404, "MEMBER_NOT_FOUND")
        if member.role == "admin" and member.enabled and (not body.enabled or body.role != "admin"):
            admins = db.scalar(select(func.count()).select_from(User).where(User.role == "admin", User.enabled.is_(True)))
            if admins <= 1:
                raise HTTPException(409, "LAST_ADMIN_REQUIRED")
        member.enabled, member.role = body.enabled, body.role
        db.execute(delete(Session).where(Session.user_id == ident))
        db.execute(delete(Link).where(Link.user_id == ident))
        db.execute(delete(Confirmation).where(Confirmation.user_id == ident))
        emit(db, "SECURITY", f"MEMBER UPDATED: {member.username} / {body.role} / {body.enabled}", actor=user.username)
        return member_dict(member)


@app.post("/api/simulation/fault")
def fault(body: FaultRequest, user=Depends(require_admin)):
    with transaction() as db:
        scene = authorized_scene(db, user, admin=True)
        before = deepcopy(scene.data)
        n = node(scene, body.node_id)
        n["fault"] = body.fault
        n["version"] += 1
        recompute(scene)
        changes(db, scene, before, "SYSTEM", f"FAULT {'SET' if body.fault else 'CLEARED'}", n["id"], user.username)
        return {"ok": True}


@app.post("/api/simulation")
def simulation(body: SimulationRequest, user=Depends(require_admin)):
    with transaction() as db:
        scene = authorized_scene(db, user, admin=True)
        before = deepcopy(scene.data)
        if body.action == "reset":
            history = deepcopy(scene.data["alerts"])
            for a in history:
                if a["state"] != "RESOLVED":
                    a.update(state="RESOLVED", resolved_at=now().isoformat(), resolution="SCENE_RESET")
            scene.data = initial_scene()
            scene.data["alerts"] = history
            scene.generation += 1
            scene.tick, scene.paused = 0, False
            db.execute(delete(Link))
            db.execute(delete(Confirmation))
            db.execute(delete(Scan))
        elif body.action == "scenario":
            n = node(scene, "DEV-01")
            n["fault"] = "OUTPUT_FAILURE"
            n["version"] += 1
            node(scene, "CAM-02")["fault"] = "SIGNAL_LOSS"
            node(scene, "CAM-02")["version"] += 1
            node(scene, "SEN-03")["fault"] = "THERMAL_HIGH"
            node(scene, "SEN-03")["version"] += 1
            recompute(scene)
        else:
            scene.paused = body.action == "pause"
        changes(db, scene, before, "SYSTEM", f"SCENE {body.action.upper()}", actor=user.username)
        return snapshot(db)


def stream_batch(token, cursor):
    user_for_token(token)
    with transaction() as db:
        # A shared scene lock makes cursor/state reads consistent with committed writers.
        state = snapshot(db)
        oldest = db.scalar(select(func.min(Event.id))) or 0
        if cursor > state["cursor"] or cursor < oldest - 1:
            return {"type": "snapshot", "snapshot": state}
        events = [event_dict(e) for e in db.scalars(select(Event).where(Event.id > cursor).order_by(Event.id).limit(200))]
        return {"type": "events", "events": events, "cursor": events[-1]["cursor"] if events else cursor}


@app.websocket("/api/stream")
async def stream(ws: WebSocket, after: int = 0):
    header = ws.headers.get("authorization", "")
    token = header[7:] if header.startswith("Bearer ") else ""
    try:
        await asyncio.to_thread(user_for_token, token)
    except HTTPException:
        await ws.close(code=4401)
        return
    await ws.accept()
    cursor = max(0, after)
    try:
        while True:
            packet = await asyncio.to_thread(stream_batch, token, cursor)
            if packet["type"] == "snapshot":
                cursor = packet["snapshot"]["cursor"]
            else:
                cursor = packet["cursor"]
            await ws.send_json(packet)
            # Detect disconnected clients even while the simulator is paused.
            try:
                incoming = await asyncio.wait_for(ws.receive_text(), timeout=1.0)
                if incoming == "close":
                    break
            except asyncio.TimeoutError:
                pass
    except HTTPException:
        await ws.close(code=4401)
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        # Any transport loss requires a fresh Link, even with a valid login session.
        try:
            with transaction() as db:
                session = db.get(Session, token_hash(token))
                if session:
                    for link in db.scalars(select(Link).where(Link.session_hash == session.token_hash)):
                        link.revoked = True
        except Exception:
            logger.exception("Failed to revoke links after stream disconnect")
