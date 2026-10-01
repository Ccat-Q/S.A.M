"""Original facility: four industrial modules, not the game's station."""


def initial_scene():
    nodes = []
    types = [("CAMERA", "CAM", 8), ("DEVICE", "DEV", 12), ("SENSOR", "SEN", 6),
             ("SERVER", "SRV", 4), ("ROBOT", "ROB", 3), ("NETWORK", "NET", 5),
             ("MODULE", "MOD", 4)]
    caps = {"CAMERA": ["diagnostic", "restart", "recover", "pan", "tilt", "zoom"],
            "SENSOR": ["diagnostic", "restart", "recover"], "SERVER": ["diagnostic", "restart", "recover"],
            "ROBOT": ["diagnostic", "restart", "recover"], "NETWORK": ["diagnostic", "restart", "recover", "disconnect"],
            "MODULE": ["diagnostic"]}
    for kind, prefix, count in types:
        for i in range(count):
            ident = f"{prefix}-{i + 1:02}"
            module = f"MOD-{i % 4 + 1:02}"
            subtype = kind
            controls = {"connected": True, "power": True, "pan": 0.0, "tilt": 0.0, "zoom": 1.0}
            capabilities = caps.get(kind, ["diagnostic", "restart"])
            if kind == "DEVICE":
                module = f"MOD-{i // 3 + 1:02}"
                subtype = ["POWER", "DOOR", "LIGHT"][i % 3]
                capabilities = {"POWER": ["power", "recover", "diagnostic"],
                                "DOOR": ["door", "diagnostic"],
                                "LIGHT": ["brightness", "diagnostic"]}[subtype]
                controls.update({"door": "closed", "brightness": 65})
            if kind == "MODULE":
                module = ident
            nodes.append({"id": ident, "name": "AI CORE" if ident == "SRV-01" else ident,
                          "type": kind, "subtype": subtype, "module_id": module,
                          "status": "ONLINE", "version": 1, "fault": None,
                          "position": {"x": (i % 3 + 1) / 4, "y": ((i // 3) % 3 + 1) / 4},
                          "capabilities": capabilities, "controls": controls,
                          "telemetry": {"power": 96.2, "temperature": 34.0, "latency": 18,
                                        "signal": 92, "fps": 30, "uptime": 0},
                          "metadata": {"model": f"SAM-{subtype}-SIM", "firmware": "1.0.0",
                                       "simulated": True}, "last_command": None})
    edges = []
    for node in nodes:
        if node["id"] not in ("NET-01", "MOD-01", "MOD-02", "MOD-03", "MOD-04"):
            gateway = "NET-01" if node["type"] == "NETWORK" else f"NET-{int(node['module_id'][-2:]) + 1:02}"
            edges.append({"source": gateway, "target": node["id"], "kind": "NETWORK"})
        if node["type"] in ("CAMERA", "SENSOR", "SERVER", "ROBOT"):
            supply = ["DEV-01", "DEV-04", "DEV-07", "DEV-10"][int(node["module_id"][-2:]) - 1]
            edges.append({"source": supply, "target": node["id"], "kind": "POWER"})
    cameras = {}
    for cam in [n for n in nodes if n["type"] == "CAMERA"]:
        targets = [n for n in nodes if n["module_id"] == cam["module_id"] and n["type"] == "DEVICE"]
        cameras[cam["id"]] = [{"node_id": n["id"], "x": 0.15 + j * 0.27, "y": 0.28 + (j % 2) * 0.2,
                              "width": 0.2, "height": 0.25} for j, n in enumerate(targets)]
    return {"nodes": nodes, "edges": edges, "camera_targets": cameras, "alerts": []}
