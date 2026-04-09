#!/usr/bin/env bash

set -euo pipefail

body="{\"now\":\"$(date -Iseconds)\"}"

print_response_json "200" "OK" "${body}"

exit 0

