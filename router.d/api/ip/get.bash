#!/usr/bin/env bash

set -euo pipefail

body="{\"ip\": \"${REMOTE_ADDR}\"}"

print_response_json "200" "OK" "${body}"

exit 0

