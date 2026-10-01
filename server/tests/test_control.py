from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from uuid import uuid4

from sqlalchemy import select

from sam.models import Confirmation, Link, now
from sam.store import transaction
from conftest import login


def request_for(client, headers, ident="DEV-02", action="door", value="open"):
    scan = client.post(f"/api/nodes/{ident}/scan", headers=headers).json()
    link = client.post("/api/links", headers=headers, json={"node_id": ident, "generation": scan["generation"], "scan_id": scan["scan_id"]})
    assert link.status_code == 200, link.text
    return {"node_id": ident, "link_id": link.json()["id"], "action": action, "value": value,
            "expected_version": scan["node"]["version"], "key": str(uuid4())}


def confirmed(client, headers, req):
    result = client.post("/api/commands/prepare", headers=headers, json=req)
    assert result.status_code == 200, result.text
    return {**req, "confirmation_id": result.json()["confirmation_id"]}


def test_seed_and_permissions(client, admin):
    snap = client.get("/api/snapshot", headers=admin).json()
    assert len(snap["nodes"]) == 42
    assert len({n["id"] for n in snap["nodes"]}) == 42
    observer = login(client, "observer")
    assert client.post("/api/nodes/DEV-02/scan", headers=observer).status_code == 200
    assert client.post("/api/links", headers=observer, json={"node_id": "DEV-02", "generation": 1, "scan_id": "invalid"}).status_code == 403
    assert client.post("/api/links", headers=admin, json={"node_id": "DEV-02", "generation": 1, "scan_id": "invalid"}).status_code == 409
    assert client.get("/api/snapshot").status_code == 401


def test_link_version_idempotency_and_five_clients(client, admin):
    headers = [login(client, "operator") for _ in range(5)]
    requests = [request_for(client, h) for h in headers]
    with ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(lambda pair: client.post("/api/commands", headers=pair[0], json=pair[1]), zip(headers, requests)))
    assert sorted(r.status_code for r in results) == [200, 409, 409, 409, 409]
    winner = next(i for i, r in enumerate(results) if r.status_code == 200)
    retried = client.post("/api/commands", headers=headers[winner], json=requests[winner])
    assert retried.json()["id"] == results[winner].json()["id"]
    assert client.post("/api/commands", headers=headers[winner], json={**requests[winner], "value": "closed"}).status_code == 409


def test_alert_ack_control_recovery(client, admin):
    client.post("/api/simulation", headers=admin, json={"action": "scenario"})
    snap = client.get("/api/snapshot", headers=admin).json()
    alert = next(a for a in snap["alerts"] if a["node_id"] == "DEV-01")
    ack = client.post(f"/api/alerts/{alert['id']}/acknowledge", headers=admin).json()
    assert ack["state"] == "ACKNOWLEDGED"
    req = request_for(client, admin, "DEV-01", "recover", None)
    assert client.post("/api/commands", headers=admin, json=req).status_code == 409
    result = client.post("/api/commands", headers=admin, json=confirmed(client, admin, req))
    assert result.json()["state"] == "SUCCEEDED"
    snap = client.get("/api/snapshot", headers=admin).json()
    assert next(a for a in snap["alerts"] if a["id"] == alert["id"])["state"] == "RESOLVED"
    assert next(n for n in snap["nodes"] if n["id"] == "CAM-01")["status"] == "ONLINE"
    logs = client.get("/api/logs", headers=admin, params={"node_id": "DEV-01"}).json()
    assert any(e["correlation_id"] == result.json()["id"] for e in logs)


def test_impact_expiry_and_reset(client, admin):
    req = request_for(client, admin, "DEV-01", "power", False)
    prepared = confirmed(client, admin, req)
    client.post("/api/simulation/fault", headers=admin, json={"node_id": "CAM-01", "fault": "SIGNAL_LOSS"})
    assert client.post("/api/commands", headers=admin, json=prepared).json()["detail"] == "IMPACT_CHANGED"
    with transaction() as db:
        db.scalar(select(Link).where(Link.id == req["link_id"])).last_used = now() - timedelta(minutes=6)
    assert client.post("/api/commands", headers=admin, json=req).json()["detail"] == "LINK_EXPIRED"
    req = request_for(client, admin, "DEV-01", "power", False)
    prepared = confirmed(client, admin, req)
    with transaction() as db:
        db.get(Confirmation, prepared["confirmation_id"]).expires_at = now() - timedelta(seconds=1)
    assert client.post("/api/commands", headers=admin, json=prepared).status_code == 409
    client.post("/api/simulation", headers=admin, json={"action": "reset"})
    assert client.post("/api/commands", headers=admin, json=req).json()["detail"] == "LINK_REQUIRED"
    assert client.get("/api/snapshot", headers=admin).json()["generation"] == 2


def test_disabled_member_and_last_admin(client, admin):
    operator = login(client, "operator")
    members = client.get("/api/members", headers=admin).json()
    user = next(u for u in members if u["username"] == "operator")
    client.patch(f"/api/members/{user['id']}", headers=admin, json={"enabled": False, "role": "observer"})
    assert client.get("/api/snapshot", headers=operator).status_code == 401
    user = next(u for u in members if u["username"] == "admin")
    assert client.patch(f"/api/members/{user['id']}", headers=admin, json={"enabled": False, "role": "admin"}).status_code == 409


def test_websocket_replay_and_disconnect_revokes_link(client, admin):
    cursor = client.get("/api/snapshot", headers=admin).json()["cursor"]
    with client.websocket_connect(f"/api/stream?after={cursor}", headers=admin) as ws:
        req = request_for(client, admin)
        packet = ws.receive_json()
        while not packet.get("events"):
            packet = ws.receive_json()
        assert any(e["message"] == "CONTROL LINK ESTABLISHED" for e in packet["events"])
        ws.send_text("close")
    assert client.post("/api/commands", headers=admin, json=req).json()["detail"] == "LINK_REQUIRED"


def test_snapshot_recovery_and_failure(client, admin):
    with client.websocket_connect("/api/stream?after=999999", headers=admin) as ws:
        assert ws.receive_json()["type"] == "snapshot"
        ws.send_text("close")
    client.post("/api/simulation/fault", headers=admin, json={"node_id": "DEV-01", "fault": "OUTPUT_FAILURE"})
    req = request_for(client, admin, "DEV-01", "power", True)
    result = client.post("/api/commands", headers=admin, json=req).json()
    assert result["state"] == "FAILED"
    assert client.get(f"/api/commands/by-key/{req['key']}", headers=admin).json()["id"] == result["id"]


def test_restart_preserves_state_and_audit_but_invalidates_link(client, admin):
    from fastapi.testclient import TestClient
    from sam.api import app
    req = request_for(client, admin)
    result = client.post("/api/commands", headers=admin, json=req).json()
    with TestClient(app) as restarted:
        snap = restarted.get("/api/snapshot", headers=admin).json()
        assert next(n for n in snap["nodes"] if n["id"] == "DEV-02")["controls"]["door"] == "open"
        assert restarted.get(f"/api/commands/by-key/{req['key']}", headers=admin).json()["id"] == result["id"]
        assert restarted.post("/api/commands", headers=admin, json={**req, "key": str(uuid4()), "expected_version": 2}).json()["detail"] == "LINK_REQUIRED"


def test_link_belongs_to_login_session_not_just_member(client, admin):
    a, b = login(client, "operator"), login(client, "operator")
    req = request_for(client, a)
    assert client.post("/api/commands", headers=b, json=req).json()["detail"] == "LINK_REQUIRED"
    with client.websocket_connect("/api/stream?after=0", headers=b) as ws:
        ws.receive_json()
        ws.send_text("close")
    assert client.post("/api/commands", headers=a, json=req).status_code == 200


def test_scan_receipt_cannot_cross_sessions_and_log_filters(client, admin):
    a, b = login(client, "operator"), login(client, "operator")
    scan = client.post("/api/nodes/DEV-02/scan", headers=a).json()
    request = {"node_id": "DEV-02", "scan_id": scan["scan_id"], "generation": scan["generation"]}
    assert client.post("/api/links", headers=b, json=request).json()["detail"] == "SCAN_REQUIRED"
    records = client.get("/api/logs", headers=admin, params={"node_id": "DEV-02", "category": "DEVICE", "q": "IDENTIFIED"}).json()
    assert len(records) == 1
    assert records[0]["actor"] == "operator"
    assert client.get("/api/logs", headers=admin, params={"since": "2026-01-01"}).status_code == 422
