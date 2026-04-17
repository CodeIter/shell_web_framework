#!/usr/bin/env bash

set -euo pipefail

[[ -f .env ]] && source .env

export BASH_HOST="${BASH_HOST:-127.0.0.1}"
export BASH_PORT="${BASH_PORT:-8080}"
export PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-${KOYEB_PUBLIC_DOMAIN:-${BASH_HOST}:${BASH_PORT}}}"

export SESSION_DIR="${SESSION_DIR:-sessions}"
export SESSION_TTL="${SESSION_TTL:-86400}" # 1 day

export SESSION_SECRET="${SESSION_SECRET:-change-this-secret-in-env}"

export UPLOAD_DIR="${UPLOAD_DIR:-tmp/uploads}"
export UPLOAD_MAX_SIZE="${UPLOAD_MAX_SIZE:-10485760}" # 10 MiB

# Keep the request body limit at least a bit above the upload limit
export MAX_BODY="${MAX_BODY:-$((UPLOAD_MAX_SIZE + 65536))}"

export SHORTENER_DATA_DIR="${SHORTENER_DATA_DIR:-data}"
export SHORTENER_DB_FILE="${SHORTENER_DB_FILE:-${SHORTENER_DATA_DIR}/url_shortener.db}"
export SHORTENER_PUBLIC_BASE_URL="${SHORTENER_PUBLIC_BASE_URL:-http://${PUBLIC_DOMAIN}}"
if [[ -n "${KOYEB_PUBLIC_DOMAIN:-}" ]] ; then
  export SHORTENER_PUBLIC_BASE_URL="https://${PUBLIC_DOMAIN}"
fi

