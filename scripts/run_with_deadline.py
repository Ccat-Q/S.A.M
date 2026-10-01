"""Bound a CI subprocess and its descendants, including a hung Flutter driver."""
import argparse
import os
import signal
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--seconds", required=True, type=int)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
if not args.command or args.seconds <= 0:
    parser.error("a positive deadline and command are required")
process = subprocess.Popen(args.command, start_new_session=True)
try:
    sys.exit(process.wait(timeout=args.seconds))
except subprocess.TimeoutExpired:
    print(f"::error::CI command exceeded {args.seconds}s; terminating process group.", flush=True)
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)
    sys.exit(124)
