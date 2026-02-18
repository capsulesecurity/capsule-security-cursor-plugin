#!/usr/bin/env bash
# Capsule Security — forward hook event to the Capsule Security API.
# All hooks except sessionStart pipe their JSON payload via stdin.

set -euo pipefail

DOMAIN="${CAPSULE_SECURITY_DOMAIN:-agentsecurity.dev-eu-west1.capsulesecurity.dev}"
TOKEN="${CAPSULE_SECURITY_JWT:?CAPSULE_SECURITY_JWT is not set. Configure it in your environment to authenticate with Capsule Security.}"

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d @- \
  "https://${DOMAIN}/v2/cursor/hooks/events"
