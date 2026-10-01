"""Stop this workflow before the user's fifteen-minute execution budget expires."""
import json
import os
import time
from datetime import datetime
from urllib.request import Request, urlopen

base = f"https://api.github.com/repos/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
headers = {"Authorization": f"Bearer {os.environ['GH_TOKEN']}",
           "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}


def request(suffix="", method="GET"):
    with urlopen(Request(base + suffix, headers=headers, method=method), timeout=10) as response:
        body = response.read()
        return json.loads(body) if body else {}


started = datetime.fromisoformat(request()["run_started_at"].replace("Z", "+00:00")).timestamp()
names = {"server", "ios-build", "ios-integration"}
while time.time() - started < 14 * 60:
    jobs = request("/jobs?per_page=100")["jobs"]
    relevant = {j["name"]: j["status"] for j in jobs if j["name"] in names}
    if set(relevant) == names and all(v == "completed" for v in relevant.values()):
        print("All build and verification jobs completed within the time budget.")
        break
    time.sleep(15)
else:
    print("::error::Workflow reached the 14-minute execution deadline; force-cancelling this run.", flush=True)
    request("/force-cancel", "POST")
