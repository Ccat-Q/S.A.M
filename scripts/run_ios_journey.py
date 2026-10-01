"""Attach the CI driver through persisted simulator logs, avoiding live-log races.

Called after the test application is built and the simulator is booted. The
outer process watchdog bounds launch, discovery, driver execution and cleanup.
"""
import pathlib
import re
import subprocess
import sys
import time
from urllib.parse import urlparse

device = sys.argv[1]
bundle = "dev.ccatq.samClient"
root = pathlib.Path(__file__).resolve().parents[1]
client = root / "client"
diagnostic = root / "artifacts/simulator-startup.log"


def simctl(*args, timeout=20, **kwargs):
    return subprocess.run(["xcrun", "simctl", *args], timeout=timeout, **kwargs)


try:
    simctl("install", device, str(client / "build/ios/iphonesimulator/Runner.app"), timeout=45, check=True)
    simctl("launch", device, bundle, "--start-paused", "--enable-checked-mode",
           "--verify-entry-points", "--disable-vm-service-publication", timeout=60, check=True)
    deadline = time.monotonic() + 45
    uri = None
    while time.monotonic() < deadline:
        result = simctl("spawn", device, "log", "show", "--last", "1m", "--style", "compact",
                        "--predicate", 'process == "Runner"', capture_output=True, text=True, check=True)
        diagnostic.write_text(result.stdout + result.stderr)
        matches = re.findall(r"The Dart VM service is listening on (http://[^\s]+)", result.stdout)
        if matches:
            uri = matches[-1]
            parsed = urlparse(uri)
            if parsed.hostname != "127.0.0.1" or parsed.port is None:
                raise RuntimeError("Unexpected simulator VM service address")
            break
        time.sleep(1)
    if uri is None:
        raise RuntimeError("Simulator did not publish a VM service address within 45 seconds")
    print("Simulator VM service discovered; attaching the operator journey driver.", flush=True)
    result = subprocess.run([
        "flutter", "drive", "--verbose", "--no-pub",
        "--driver=test_driver/journey_driver.dart", "--target=integration_test/journey_test.dart",
        f"--use-existing-app={uri}", "-d", device,
    ], cwd=client)
    sys.exit(result.returncode)
finally:
    try:
        simctl("terminate", device, bundle, timeout=10, check=False)
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f"Simulator cleanup could not complete: {error}", file=sys.stderr)
