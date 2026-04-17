#!/usr/bin/env bash

set -euo pipefail

SHORTENER_DATA_DIR="${SHORTENER_DATA_DIR:-data}"
SHORTENER_DB_FILE="${SHORTENER_DB_FILE:-${SHORTENER_DATA_DIR}/url_shortener.db}"

shortener_init_store() {
  mkdir -p "${SHORTENER_DATA_DIR}"
  touch "${SHORTENER_DB_FILE}"
}

shortener_trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

shortener_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

shortener_normalize_url() {
  local url
  url="$(shortener_trim "${1:-}")"
  [[ -z "${url}" ]] && return 1

  if [[ "${url}" != *"://"* ]]; then
    url="https://${url}"
  fi

  printf '%s' "${url}"
}

shortener_generate_id() {
  local id
  # Robust generation of 8 alphanumeric chars WITHOUT SIGPIPE / "tr:
  # write error: Broken pipe"
  # (head produces finite input → tr never gets a closed pipe)
  while :; do
    id="$(head -c 32 /dev/urandom 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c 8)"
    if [[ "${#id}" -eq 8 ]] ; then
      printf '%s' "$id"
      return 0
    fi
  done
}

shortener_db_encode() {
  printf '%s' "${1:-}" | base64 | tr -d '\n'
}

shortener_db_decode() {
  printf '%s' "${1:-}" | base64 -d
}

shortener_lookup_url() {
  local short_id="${1:-}"
  local encoded

  shortener_init_store
  encoded="$(awk -F $'\t' -v id="$short_id" '$1==id {print $2; exit}' "${SHORTENER_DB_FILE}" 2>/dev/null || true)"
  [[ -z "${encoded}" ]] && return 1

  shortener_db_decode "${encoded}"
}

shortener_store_url() {
  local url="${1:-}"
  local short_id="${2:-}"
  local encoded ts

  shortener_init_store
  encoded="$(shortener_db_encode "${url}")"
  ts="$(date -Iseconds)"

  if [[ -n "${short_id}" ]]; then
    if grep -qE "^${short_id}[[:space:]]" "${SHORTENER_DB_FILE}"; then
      return 1
    fi
  else
    while :; do
      short_id="$(shortener_generate_id)"
      [[ -z "${short_id}" ]] && continue
      if ! grep -qE "^${short_id}[[:space:]]" "${SHORTENER_DB_FILE}"; then
        break
      fi
    done
  fi

  printf '%s\t%s\t%s\n' "${short_id}" "${encoded}" "${ts}" >> "${SHORTENER_DB_FILE}"
  printf '%s' "${short_id}"
}

shortener_public_base() {
  if [[ -n "${SHORTENER_PUBLIC_BASE_URL:-}" ]]; then
    printf '%s' "${SHORTENER_PUBLIC_BASE_URL%/}"
    return 0
  fi

  local scheme="http"
  [[ "${REQUEST_HEADERS[x-forwarded-proto]:-}" == "https" ]] && scheme="https"
  printf '%s://%s' "${scheme}" "${REQUEST_HEADERS[host]:-${BASH_HOST}:${BASH_PORT}}"
}

shortener_public_url() {
  printf '%s/r/%s' "$(shortener_public_base)" "${1:-}"
}

