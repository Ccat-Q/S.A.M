import asyncio
import logging
import math
import time
from copy import deepcopy

from .config import settings
from .control import changes, recompute
from .store import locked_scene, purge, transaction

logger = logging.getLogger(__name__)


def tick():
    with transaction() as db:
        scene = locked_scene(db)
        if scene.paused:
            return
        before = deepcopy(scene.data)
        scene.tick += 1
        for i, n in enumerate(scene.data["nodes"]):
            telemetry = n["telemetry"]
            telemetry.update(power=round(96 + 1.2 * math.sin((scene.tick + i) / 19), 1),
                             temperature=round(34 + 6 * math.sin((scene.tick + i) / 13), 1),
                             latency=18 + (scene.tick + i) % 9,
                             signal=90 + (scene.tick + i) % 8,
                             uptime=telemetry["uptime"] + int(settings.tick_seconds))
            if n["fault"] == "THERMAL_HIGH":
                telemetry["temperature"] = 86.0
            if n["status"] == "OFFLINE":
                telemetry.update(signal=0, fps=0)
            else:
                telemetry["fps"] = 30
        recompute(scene)
        changes(db, scene, before, "TELEMETRY", "SENSOR FRAME RECEIVED")
        if scene.tick % 1800 == 0:
            purge(db)


async def run():
    last_purge = time.monotonic()
    while True:
        await asyncio.sleep(settings.tick_seconds)
        try:
            await asyncio.to_thread(tick)
            if time.monotonic() - last_purge >= 3600:
                def maintenance():
                    with transaction() as db:
                        purge(db)
                await asyncio.to_thread(maintenance)
                last_purge = time.monotonic()
        except Exception:
            logger.exception("Simulation tick failed; retrying on next tick")
