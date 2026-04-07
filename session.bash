#!/usr/bin/env bash

set -euo pipefail

session_init() {
  mkdir -p "${SESSION_DIR}"
}

session_path() {
  printf '%s/%s.session' "${SESSION_DIR}" "$1"
}

session_new() {
  declare -gA SESSION=()
  SESSION_ID="$(rand_hex)"
  SESSION_EXPIRES="$(( $(now_epoch) + SESSION_TTL ))"
}

session_put() {
  local key="$1"
  local value="$2"
  SESSION["$key"]="$value"
}

session_save() {
  session_init
  local path tmp
  path="$(session_path "${SESSION_ID}")"
  tmp="${path}.tmp"

  {
    printf 'expires=%s\n' "${SESSION_EXPIRES}"
    for _k in "${!SESSION[@]}"; do
      printf '%s=%s\n' "${_k}" "$(urlencode "${SESSION[$_k]}")"
    done
  } > "${tmp}"

  mv -f "${tmp}" "${path}"
}

session_load() {
  local sid="$1" path key val
  path="$(session_path "$sid")"
  [[ -f "$path" ]] || return 1

  declare -gA SESSION=()
  SESSION_ID="$sid"
  SESSION_EXPIRES=""

  while IFS='=' read -r key val; do
    [[ -z "${key}" ]] && continue
    case "$key" in
      expires)
        SESSION_EXPIRES="$val"
        ;;
      *)
        SESSION["$key"]="$(urldecode "$val")"
        ;;
    esac
  done < "$path"

  [[ "${SESSION_EXPIRES}" =~ ^[0-9]+$ ]] || return 1
  if (( $(now_epoch) >= SESSION_EXPIRES )); then
    rm -f "$path"
    return 1
  fi
}

set_session_cookie() {
  local ttl="${1:-$SESSION_TTL}"
  local expires_http
  local exp="${SESSION_EXPIRES}"

  expires_http="$(date -u -d "@${exp}" '+%a, %d %b %Y %H:%M:%S GMT' 2>/dev/null || true)"
  if [[ -n "${expires_http}" ]]; then
    set_signed_cookie "session" "${SESSION_ID}|${exp}" "Path=/; HttpOnly; SameSite=Lax; Max-Age=${ttl}; Expires=${expires_http}"
  else
    set_signed_cookie "session" "${SESSION_ID}|${exp}" "Path=/; HttpOnly; SameSite=Lax; Max-Age=${ttl}"
  fi
}

clear_session_cookie() {
  clear_cookie "session"
}

session_load_from_cookie() {
  local token payload sid exp now

  token="${COOKIES[session]:-}"
  [[ -n "$token" ]] || return 1

  verify_payload "$token" || {
    clear_session_cookie
    return 1
  }

  payload="${token%.*}"
  sid="${payload%%|*}"
  exp="${payload#*|}"

  [[ "$payload" == "${sid}|${exp}" ]] || {
    clear_session_cookie
    return 1
  }

  [[ "$sid" =~ ^[0-9a-f]{32}$ ]] || {
    clear_session_cookie
    return 1
  }

  [[ "$exp" =~ ^[0-9]+$ ]] || {
    clear_session_cookie
    return 1
  }

  now="$(now_epoch)"
  if (( now >= exp )); then
    session_destroy "$sid" || true
    clear_session_cookie
    return 1
  fi

  session_load "$sid" || {
    clear_session_cookie
    return 1
  }

  SESSION_ID="$sid"
  SESSION_EXPIRES="$exp"
}

session_destroy() {
  local sid="$1"
  rm -f "$(session_path "$sid")"
}

