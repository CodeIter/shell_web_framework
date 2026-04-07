#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$(realpath "${0}")")" || exit

source internal.bash
source core.bash
source config.bash

# Response headers
declare -A HEADERS
export HEADERS

# Read request line
IFS=$'\r\n' read -r REQUEST_LINE || exit
export REQUEST_LINE

# Read http headers
declare -A REQUEST_HEADERS
export REQUEST_HEADERS
while IFS=$'\r\n' read -r _header && [[ -n "${_header}" ]] ; do
  _key="${_header%%:*}"
  _val="${_header#*:}"
  _key="${_key,,}"
  _key="${_key#"${_key%%[![:space:]]*}"}"
  _key="${_key%"${_key##*[![:space:]]}"}"
  _val="${_val#"${_val%%[![:space:]]*}"}"
  _val="${_val%"${_val##*[![:space:]]}"}"
  REQUEST_HEADERS["${_key}"]="${_val}"
done
unset _key _val

# Read request body (if any)
BODY_RAW=""
CONTENT_LENGTH="${REQUEST_HEADERS[content-length]:-0}"
export MAX_BODY=1048576 # 1MB
if (( CONTENT_LENGTH > MAX_BODY )); then
  echo "Received Payload too large" >&2
  _body="413 Payload too large"
  HEADERS["content-type"]="text/plain"
  HEADERS["content-length"]="${#_body}"
  HEADERS["connection"]="close"
  print_status "413" "Payload too large"
  print_headers
  print_crnl
  printf "%s" "${_body}"
  exit 1
fi
if [[ "${CONTENT_LENGTH}" =~ ^[0-9]+$ ]] && (( CONTENT_LENGTH > 0 )) ; then
  IFS= read -r -n "${CONTENT_LENGTH}" BODY_RAW || true
fi
export BODY_RAW

_xff="${REQUEST_HEADERS[x-forwarded-for]:-}"
_xreal="${REQUEST_HEADERS[x-real-ip]:-}"
# If X-Forwarded-For may contain multiple IPs, take the first one (client)
if [[ -n "${_xff}" ]] ; then
  _xff="${_xff%%,*}"
  _xff="${_xff#"${_xff%%[![:space:]]*}"}"
  _xff="${_xff%"${_xff##*[![:space:]]}"}"
fi
REMOTE_ADDR="$(_pick "${_xff}" "${_xreal}" "${SOCAT_PEERADDR:-}" "${NCAT_REMOTE_ADDR:-}" "${NCAT_REMOTE_IP:-}")"
REMOTE_ADDR="${REMOTE_ADDR:-unknown}"
REMOTE_PORT="$(_pick "${REQUEST_HEADERS[x-forwarded-port]:-}" "${REQUEST_HEADERS[x-real-port]:-}" "${SOCAT_PEERPORT:-}" "${NCAT_REMOTE_PORT:-}")"
REMOTE_PORT="${REMOTE_PORT:-unknown}"

export METHOD=$(awk '{print $1}' <<<"${REQUEST_LINE}")
export REQUEST_URI=$(awk '{print $2}' <<<"${REQUEST_LINE}")
export HTTP_VERSION=$(awk '{print $3}' <<<"${REQUEST_LINE}")

METHOD="${METHOD,,}"
HTTP_VERSION="${HTTP_VERSION,,}"

if [[ "${REQUEST_URI}" == *\?* ]]; then
  export WEBPATH="${REQUEST_URI%%\?*}"
  export QUERY_RAW="${REQUEST_URI#*\?}"
else
  export WEBPATH="${REQUEST_URI}"
  export QUERY_RAW=""
fi
if [[ -z "${WEBPATH}" ]]; then
  export WEBPATH="/"
fi

WEBPATH="$(sed -sure 's~\.~~g;s~/+~/~g' <<< "${WEBPATH}")"

export ROOT="${PWD}/web"

export FILE="${ROOT}/${WEBPATH}"
FILE="$(sed -sure 's~/+~/~g' <<< "${FILE}")"
if ! [[ -f "${FILE}" ]] && [[ "${FILE}" = */ ]] ; then
  FILE+="index.html"
fi

declare -A QUERY
export QUERY
# Populate QUERY from QUERY_RAW
if [[ -n "${QUERY_RAW}" ]]; then
  IFS='&' read -r -a _pairs <<< "${QUERY_RAW}"
  for _p in "${_pairs[@]}"; do
    [[ -z "${_p}" ]] && continue
    if [[ "${_p}" == *=* ]]; then
      _key="${_p%%=*}"
      _val="${_p#*=}"
    else
      _key="${_p}"
      _val=""
    fi
    _key="$(urldecode "${_key}")"
    _val="$(urldecode "${_val}")"
    QUERY["${_key}"]="${_val}"
  done
fi
unset _key _val _p _pairs

declare -A BODY
export BODY

CONTENT_TYPE="${REQUEST_HEADERS[content-type]:-}"

# Only parse urlencoded bodies
if [[ "${METHOD}" =~ ^(post|put|patch)$ ]] && [[ "${CONTENT_TYPE}" == *"application/x-www-form-urlencoded"* ]]; then
  if [[ -n "${BODY_RAW}" ]]; then
    IFS='&' read -r -a _pairs <<< "${BODY_RAW}"
    for _p in "${_pairs[@]}"; do
      [[ -z "${_p}" ]] && continue
      if [[ "${_p}" == *=* ]]; then
        _key="${_p%%=*}"
        _val="${_p#*=}"
      else
        _key="${_p}"
        _val=""
      fi
      _key="$(urldecode "${_key}")"
      _val="$(urldecode "${_val}")"
      BODY["${_key}"]="${_val}"
    done
  fi
fi
unset _key _val _p _pairs

declare -A COOKIES
export COOKIES

COOKIE_HEADER="${REQUEST_HEADERS[cookie]:-}"

if [[ -n "${COOKIE_HEADER}" ]]; then
  IFS=';' read -r -a _pairs <<< "${COOKIE_HEADER}"
  for _p in "${_pairs[@]}"; do
    # trim spaces
    _p="${_p#"${_p%%[![:space:]]*}"}"
    _p="${_p%"${_p##*[![:space:]]}"}"
    [[ -z "${_p}" ]] && continue
    if [[ "${_p}" == *=* ]]; then
      _key="${_p%%=*}"
      _val="${_p#*=}"
    else
      _key="${_p}"
      _val=""
    fi
    _key="$(urldecode "${_key}")"
    _val="$(urldecode "${_val}")"
    COOKIES["${_key}"]="${_val}"
  done
fi
unset _key _val _p _pairs

for _f in ./middleware.d/* ; do
  if [[ -f "${_f}" ]] ; then
    source "${_f}"
  fi
done

if [[ -f "./router.d${WEBPATH}/all.sh" ]] ; then
  source "./router.d${WEBPATH}/all.sh"
elif [[ -f "./router.d${WEBPATH}/all.bash" ]] ; then
  source "./router.d${WEBPATH}/all.bash"
elif [[ -f "./router.d${WEBPATH}/${METHOD}.sh" ]] ; then
  source "./router.d${WEBPATH}/${METHOD}.sh"
elif [[ -f "./router.d${WEBPATH}/${METHOD}.bash" ]] ; then
  source "./router.d${WEBPATH}/${METHOD}.bash"
fi

if [[ -f "${FILE}" ]]; then
  _ct="$(mime_type "${FILE}")"
  SIZE=$(stat -c%s "${FILE}" 2>/dev/null || wc -c <"${FILE}")
  HEADERS["content-type"]="${_ct}"
  HEADERS["content-length"]="${SIZE}"
  HEADERS["connection"]="close"
  print_status "200" "OK"
  print_headers
  print_crnl
  cat "${FILE}"
elif [[ -d "${ROOT}/${WEBPATH}" ]] ; then
  for _f in "${ROOT}/${WEBPATH}"/*.sh "${ROOT}/${WEBPATH}"/*.bash ; do
    source "${_f}"
  done
  unset _f
elif [[ -f "${ROOT}/404.html" ]] ; then
  FILE="${ROOT}/404.html"
  _ct="$(mime_type "${FILE}")"
  SIZE=$(stat -c%s "${FILE}" 2>/dev/null || wc -c <"${FILE}")
  HEADERS["content-type"]="${_ct}"
  HEADERS["content-length"]="${SIZE}"
  HEADERS["connection"]="close"
  print_status "404" "Not Found"
  print_headers
  print_crnl
  cat "${FILE}"
else
  _body="404 Not Found"
  HEADERS["content-type"]="text/plain"
  HEADERS["content-length"]="${#_body}"
  HEADERS["connection"]="close"
  print_status "404" "Not Found"
  print_headers
  print_crnl
  printf "%s" "${_body}"
fi
unset _ct _body

exit

