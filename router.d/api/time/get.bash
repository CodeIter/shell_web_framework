#!/usr/bin/env bash

set -euo pipefail

body="{\"now\":\"$(date -Iseconds)\"}"

HEADERS["content-type"]="application/json"
HEADERS["content-length"]="${#body}"

print_status "200" "OK"
print_headers
print_crnl
printf '%s' "$body"

exit 0

