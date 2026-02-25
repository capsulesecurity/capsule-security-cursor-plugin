#!/usr/bin/env bash
# Capsule Security — forward gating hook event to the Capsule Security API.
# Used for pre-execution hooks (beforeMCPExecution, preToolUse) that can block actions.
# Reads the hook payload from stdin, sends it to the API, and relays the decision back.

set -euo pipefail

DOMAIN="${CAPSULE_SECURITY_DOMAIN:-agentsecurity.us-east1.capsulesecurity.io}"
TOKEN="${CAPSULE_SECURITY_JWT:?CAPSULE_SECURITY_JWT is not set. Configure it in your environment to authenticate with Capsule Security.}"

PAYLOAD=$(cat)

RESPONSE=$(printf '%s' "$PAYLOAD" | curl -s -w '\n%{http_code}' -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d @- \
  "https://${DOMAIN}/v2/cursor/hooks/events")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ] && [ -n "$BODY" ]; then
  echo "$BODY"
else
  # Fail-open: allow the action if the API is unreachable or returns an error
  echo '{"continue": true}'
fi
