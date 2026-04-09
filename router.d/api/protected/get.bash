#!/usr/bin/env bash

set -euo pipefail

user="${SESSION[username]:-}"
if [[ -z "$user" ]]; then
  body='{"error":"unauthorized"}'
  print_response_json "401" "Unauthorized" "${body}"
  exit 0
fi

body='{"hello":"'"$user"'"}'
print_response_json "200" "OK" "${body}"
exit 0

