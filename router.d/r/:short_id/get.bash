#!/usr/bin/env bash

set -euo pipefail

short_id="${ROUTE_PARAMS[short_id]:-}"

if [[ -z "${short_id}" || ! "${short_id}" =~ ^[A-Za-z0-9]{4,32}$ ]] ; then
  print_response_html "404" "Not Found" "<h1>1 404 Not Found</h1>"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../" && pwd)"
source "${ROOT_DIR}/url_shortener_helpers.bash"

shortener_init_store

target_url="$(shortener_lookup_url "${short_id}" || true)"
if [[ -z "${target_url:-}" ]] ; then
  print_response_html "404" "Not Found" "<h1>2 404 Not Found</h1>"
  exit 0
fi

redirect "${target_url}" "302"

