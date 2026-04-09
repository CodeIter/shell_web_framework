#!/usr/bin/env bash

set -euo pipefail

body='{"ok":true,"path":"'"${WEBPATH}"'"}'

print_response_json "200" "OK" "${body}"

exit 0

