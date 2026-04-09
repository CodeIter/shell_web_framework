#!/usr/bin/env bash

set -euo pipefail

body="<h1>Hello World</h1>"

print_response_html "200" "OK" "${body}"

exit 0

