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
    try:
        simctl("launch", device, bundle, "--start-paused", "--enable-checked-mode",
               "--verify-entry-points", "--disable-vm-service-publication", timeout=60, check=True)
    except subprocess.TimeoutExpired:
        # simctl can stall returning the PID after launching the application.
        # A timeout alone is not readiness: the authenticated VM address and
        # both native/driver test completions below must still be verified.
        print("Simulator launch response timed out; checking persisted VM readiness.", flush=True)
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
    if result.returncode == 0:
        # The extended driver can omit a test_api tearDown failure. Require
        # the application's own completion as well as the driver exit status.
        native_deadline = time.monotonic() + 15
        while True:
            native = simctl("spawn", device, "log", "show", "--last", "3m", "--style", "compact",
                            "--predicate", 'process == "Runner"', timeout=10,
                            capture_output=True, text=True, check=True)
            (root / "artifacts/simulator-test.log").write_text(native.stdout + native.stderr)
            if "Some tests failed." in native.stdout:
                raise RuntimeError("Native Flutter test framework reported a failure; see simulator-test.log")
            if "All tests passed" in native.stdout:
                break
            if time.monotonic() >= native_deadline:
                raise RuntimeError("Native Flutter test framework did not report successful completion")
            time.sleep(1)
    sys.exit(result.returncode)
finally:
    try:
        simctl("terminate", device, bundle, timeout=10, check=False)
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f"Simulator cleanup could not complete: {error}", file=sys.stderr)
