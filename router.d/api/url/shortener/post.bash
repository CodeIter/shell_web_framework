#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"
source "${ROOT_DIR}/url_shortener_helpers.bash"

shortener_init_store

input_url="${BODY[url]:-${BODY[long_url]:-${QUERY[url]:-}}}"
input_url="$(shortener_trim "${input_url:-}")"

if [[ -z "${input_url}" ]]; then
  print_response_json "400" "Bad Request" '{"error":"missing url field named url"}'
  exit 0
fi

normalized_url="$(shortener_normalize_url "${input_url}")"
short_id="$(shortener_store_url "${normalized_url}")"
short_url="$(shortener_public_url "${short_id}")"

body="$(printf '{"ok":true,"short_id":"%s","url":"%s","short_url":"%s"}' \
  "$(shortener_json_escape "${short_id}")" \
  "$(shortener_json_escape "${normalized_url}")" \
  "$(shortener_json_escape "${short_url}")")"

print_response_json "201" "Created" "${body}"
exit 0

