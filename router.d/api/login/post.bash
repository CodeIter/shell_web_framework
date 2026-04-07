#!/usr/bin/env bash

set -euo pipefail

username="${BODY[username]:-}"
password="${BODY[password]:-}"

if [[ "$username" == "admin" && "$password" == "1234" ]]; then
  body='{"status":"ok"}'
  status=200
  msg="Ok"
  set_cookie "session" "abc123" "Path=/; HttpOnly; Max-Age=3600"
else
  body='{"status":"fail"}'
  status=401
  msg="Unauthorized"
fi

HEADERS["content-type"]="application/json"
HEADERS["content-length"]="${#body}"
HEADERS["connection"]="close"

print_status "${status}" "${msg}"
print_headers
print_crnl
printf '%s' "$body"

exit 0

