#!/usr/bin/env bash

set -euo pipefail

# Print status
print_status() {
  printf '%s %s %s\n\r' "HTTP/1.1" "${1:-200}" "${2:-OK}"
}

# Print headers
print_headers() {
  local _key _val
  for _key in "${!HEADERS[@]}"; do
    _val="${HEADERS[${_key}]}"
    # handle multi-line headers (like Set-Cookie)
    while IFS= read -r _line; do
      if [[ "${_key}" == "set-cookie" && "${_line}" == Set-Cookie:* ]]; then
        printf '%s\r\n' "${_line}"
      else
        printf '%s: %s\r\n' "${_key}" "${_line}"
      fi
    done <<< "${_val}"
  done
}

# Print newline crnl
print_crnl() {
  printf '\r\n'
}

# Cookies helper
set_cookie() {
  local name="$1"
  local value="$2"
  local opts="${3:-Path=/; HttpOnly}"
  # multiple Set-Cookie headers must not overwrite each other
  if [[ -n "${HEADERS[set-cookie]:-}" ]]; then
    HEADERS["set-cookie"]+=$'\n'"Set-Cookie: ${name}=${value}; ${opts}"
  else
    HEADERS["set-cookie"]="Set-Cookie: ${name}=${value}; ${opts}"
  fi
}

# URL-decode function
urldecode() {
  local s="${1//+/ }"
  printf '%b' "${s//%/\\x}"
}

# URL-encode helper
urlencode() {
  local s="$1" out="" c hex i
  for ((i=0; i<${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      ' ') out+='+' ;;
      *)
        printf -v hex '%02X' "'$c"
        out+="%$hex"
        ;;
    esac
  done
  printf '%s' "$out"
}

# Simple JSON getter using jq
json_get() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$BODY_RAW" | jq -r ".$key"
  else
    return 1
  fi
}

now_epoch() {
  date +%s
}

rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

hmac_sha256_hex() {
  local data="$1"
  printf '%s' "$data" \
    | openssl dgst -sha256 -hmac "${SESSION_SECRET}" -binary \
    | od -An -tx1 \
    | tr -d ' \n'
}

sign_payload() {
  local payload="$1" sig
  sig="$(hmac_sha256_hex "$payload")"
  printf '%s.%s' "$payload" "$sig"
}

verify_payload() {
  local token="$1" payload sig expected
  [[ "$token" == *.* ]] || return 1
  payload="${token%.*}"
  sig="${token##*.}"
  expected="$(hmac_sha256_hex "$payload")"
  [[ "$sig" == "$expected" ]]
}

set_signed_cookie() {
  local name="$1"
  local payload="$2"
  local opts="${3:-Path=/; HttpOnly; SameSite=Lax}"
  local token
  token="$(sign_payload "$payload")"
  set_cookie "$name" "$token" "$opts"
}

clear_cookie() {
  local name="$1"
  set_cookie "$name" "" "Path=/; HttpOnly; SameSite=Lax; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
}

# Return MIME type for a filename (prints to stdout)
mime_type() {
  local _file="$1"
  local _ct

  case "${_file,,}" in
    # HTML
    *.html|*.htm)            _ct="text/html";;

    # Stylesheets
    *.css)                   _ct="text/css";;

    # JavaScript
    *.js|*.mjs|*.cjs)        _ct="application/javascript";;

    # JSON / maps
    *.json|*.map)            _ct="application/json";;

    # XML / feeds / SVG
    *.xml)                   _ct="application/xml";;
    *.rss|*.atom)            _ct="application/rss+xml";;
    *.svg)                   _ct="image/svg+xml";;

    # Fonts
    *.woff)                  _ct="font/woff";;
    *.woff2)                 _ct="font/woff2";;
    *.ttf)                   _ct="font/ttf";;
    *.otf)                   _ct="font/otf";;
    *.eot)                   _ct="application/vnd.ms-fontobject";;

    # Images
    *.png)                   _ct="image/png";;
    *.jpg|*.jpeg)            _ct="image/jpeg";;
    *.gif)                   _ct="image/gif";;
    *.webp)                  _ct="image/webp";;
    *.avif)                  _ct="image/avif";;
    *.bmp)                   _ct="image/bmp";;
    *.ico)                   _ct="image/x-icon";;

    # Audio / Video
    *.mp3)                   _ct="audio/mpeg";;
    *.wav)                   _ct="audio/wav";;
    *.ogg)                   _ct="audio/ogg";;
    *.mp4)                   _ct="video/mp4";;
    *.webm)                  _ct="video/webm";;
    *.mov)                   _ct="video/quicktime";;

    # Archives / binary
    *.zip)                   _ct="application/zip";;
    *.tar)                   _ct="application/x-tar";;
    *.gz|*.tgz)              _ct="application/gzip";;
    *.7z)                    _ct="application/x-7z-compressed";;
    *.rar)                   _ct="application/vnd.rar";;

    # Documents
    *.pdf)                   _ct="application/pdf";;
    *.txt)                   _ct="text/plain";;
    *.csv)                   _ct="text/csv";;
    *.md)                    _ct="text/markdown";;

    # Web manifests / wasm
    *.webmanifest)           _ct="application/manifest+json";;
    *.wasm)                  _ct="application/wasm";;

    # Fallback
    *)                       _ct="application/octet-stream";;
  esac

  printf '%s' "$_ct"
}

