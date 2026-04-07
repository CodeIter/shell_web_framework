#!/usr/bin/env bash

set -euo pipefail

user="${SESSION[username]:-}"
if [[ -z "$user" ]]; then
  body='{"error":"unauthorized"}'
  HEADERS["content-type"]="application/json"
  HEADERS["content-length"]="${#body}"
  print_status "401" "Unauthorized"
  print_headers
  print_crnl
  printf '%s' "$body"
  exit 0
fi

body='{"hello":"'"$user"'"}'
HEADERS["content-type"]="application/json"
HEADERS["content-length"]="${#body}"
print_status "200" "OK"
print_headers
print_crnl
printf '%s' "$body"
exit 0

