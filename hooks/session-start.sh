#!/usr/bin/env bash
# Capsule Security — session start hook.
# Collects MCP configuration files from workspace .cursor/projects directories
# and forwards them alongside the hook payload to the Capsule Security API.

set -euo pipefail

DOMAIN="${CAPSULE_SECURITY_DOMAIN:-agentsecurity.dev-eu-west1.capsulesecurity.dev}"
TOKEN="${CAPSULE_SECURITY_JWT:?CAPSULE_SECURITY_JWT is not set. Configure it in your environment to authenticate with Capsule Security.}"

export CAPSULE_ENDPOINT="https://${DOMAIN}/v2/cursor/hooks/events"
export CAPSULE_TOKEN="${TOKEN}"

$(command -v python3 || command -v python) -c '
import sys, json, os, base64, urllib.request, traceback

hook = json.load(sys.stdin)
ws_roots = hook.get("workspace_roots", [])

cursor_roots = [os.path.join(ws, ".cursor") for ws in ws_roots] + [
    os.path.expanduser("~/.cursor")
]

files_dict = {}
errors = []

for cr in cursor_roots:
    for p in ws_roots:
        project_dir = os.path.join(cr, "projects", p.strip(os.sep).replace(os.sep, "-"))
        if not os.path.exists(project_dir):
            continue
        for root, dirs, files in os.walk(project_dir):
            if "mcps" not in root:
                continue
            for f in files:
                if not f.endswith((".json", ".md")):
                    continue
                filepath = os.path.join(root, f)
                try:
                    files_dict[filepath] = open(filepath, "rb").read().decode("utf-8", "ignore")
                except Exception:
                    errors.append({"filepath": filepath, "error": traceback.format_exc()})

endpoint = os.environ["CAPSULE_ENDPOINT"]
token = os.environ["CAPSULE_TOKEN"]

payload = {
    "hook": hook,
    "mcp_files": base64.b64encode(json.dumps(files_dict).encode()).decode(),
    "errors": errors,
}

try:
    req = urllib.request.Request(
        endpoint,
        json.dumps(payload).encode(),
        {"Content-Type": "application/json", "Authorization": "Bearer " + token},
    )
    urllib.request.urlopen(req)
except Exception:
    try:
        error_payload = {
            "hook": hook,
            "mcp_files": "",
            "errors": errors + [{"filepath": "SEND_PAYLOAD", "error": traceback.format_exc()}],
        }
        req = urllib.request.Request(
            endpoint,
            json.dumps(error_payload).encode(),
            {"Content-Type": "application/json", "Authorization": "Bearer " + token},
        )
        urllib.request.urlopen(req)
    except Exception:
        pass
'
