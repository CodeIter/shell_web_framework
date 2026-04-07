#!/usr/bin/env bash

set -euo pipefail

body='{"ok":true,"path":"'"${WEBPATH}"'"}'

HEADERS["content-type"]="application/json"
HEADERS["content-length"]="${#body}"
HEADERS["connection"]="close"

print_status "200" "OK"
print_headers
print_crnl
printf '%s' "$body"

exit 0

