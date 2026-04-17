#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$(realpath "${0}")")" || exit

source internal.bash
source session.bash

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
BODY_FILE=""
_content_length="${REQUEST_HEADERS[content-length]:-0}"

export UPLOAD_DIR="${UPLOAD_DIR:-tmp/uploads}"
export UPLOAD_MAX_SIZE="${UPLOAD_MAX_SIZE:-10485760}" # 10 MiB
export MAX_BODY="${MAX_BODY:-$((UPLOAD_MAX_SIZE + 65536))}"
if (( MAX_BODY < UPLOAD_MAX_SIZE + 65536 )); then
  MAX_BODY="$((UPLOAD_MAX_SIZE + 65536))"
fi

if (( _content_length > MAX_BODY )); then
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

BODY_FILE="$(mktemp tmp/body-XXXXXX)"
trap '[[ -n "${BODY_FILE:-}" && -f "${BODY_FILE}" ]] && rm -f "${BODY_FILE}"' EXIT

if [[ "${_content_length}" =~ ^[0-9]+$ ]] && (( _content_length > 0 )) ; then
  dd bs=1 count="${_content_length}" of="${BODY_FILE}" 2>/dev/null || true
else
  : > "${BODY_FILE}"
fi

export BODY_FILE
unset _content_length

declare -A UPLOAD_PATH
declare -A UPLOAD_NAME
declare -A UPLOAD_TYPE
declare -A UPLOAD_SIZE
export UPLOAD_PATH UPLOAD_NAME UPLOAD_TYPE UPLOAD_SIZE

_xff="${REQUEST_HEADERS[x-forwarded-for]:-}"
_xreal="${REQUEST_HEADERS[x-real-ip]:-}"
# If X-Forwarded-For may contain multiple IPs, take the first one (client)
if [[ -n "${_xff}" ]] ; then
  _xff="${_xff%%,*}"
  _xff="${_xff#"${_xff%%[![:space:]]*}"}"
  _xff="${_xff%"${_xff##*[![:space:]]}"}"
fi
export REMOTE_ADDR="$(_pick "${_xff}" "${_xreal}" "${SOCAT_PEERADDR:-}" "${NCAT_REMOTE_ADDR:-}" "${NCAT_REMOTE_IP:-}")"
unset _xff _xreal
REMOTE_ADDR="${REMOTE_ADDR:-unknown}"
export REMOTE_PORT="$(_pick "${REQUEST_HEADERS[x-forwarded-port]:-}" "${REQUEST_HEADERS[x-real-port]:-}" "${SOCAT_PEERPORT:-}" "${NCAT_REMOTE_PORT:-}")"
REMOTE_PORT="${REMOTE_PORT:-unknown}"
export REMOTE_PROTO="$(_pick "${REQUEST_HEADERS[x-forwarded-proto]:-}" "http")"
export REMOTE_HOST="$(_pick "${REQUEST_HEADERS[x-forwarded-host]:-}" "${REQUEST_HEADERS[host]}")"

REMOTE_PROTO="${REMOTE_PROTO,,}"
REMOTE_HOST="${REMOTE_HOST,,}"

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

WEBPATH="$(sed -Ee 's~/\.\.?/~/~g;s~/+~/~g' <<< "${WEBPATH}")"

export ROOT="${PWD}/web"

export FILE="${ROOT}/${WEBPATH}"
FILE="$(sed -Ee 's~/+~/~g' <<< "${FILE}")"
if ! [[ -f "${FILE}" ]] ; then
  FILE+="/index.html"
fi
FILE="$(sed -Ee 's~/+~/~g' <<< "${FILE}")"

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

# Only parse urlencoded bodies
_content_type="${REQUEST_HEADERS[content-type]:-}"
if [[ "${METHOD}" =~ ^(post|put|patch)$ ]] ; then
  if [[ "${_content_type}" == *"application/x-www-form-urlencoded"* ]]; then
    BODY_RAW="$(cat "${BODY_FILE}")"
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
  elif [[ "${_content_type}" == multipart/form-data* ]]; then
    if [[ "${_content_type}" =~ boundary=\"?([^\";[:space:]]+)\"? ]]; then
      _boundary="${BASH_REMATCH[1]}"
      _parse_multipart_form "${BODY_FILE}" "${_boundary}"
    fi
  fi
fi
unset _key _val _p _pairs _content_type _boundary

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

declare -A SESSION
export SESSION

if [[ -n "${COOKIES[session]:-}" ]]; then
  session_load_from_cookie || true
fi

export SESSION_ID SESSION_EXPIRES

for _f in ./middleware.d/* ; do
  if [[ -f "${_f}" ]] ; then
    source "${_f}"
  fi
done

# === GENERIC DYNAMIC ROUTER (with :param support) ===
#
# - Exact routes continue to work unchanged (api/ip/get.bash, etc.)
# - Dynamic paths are now supported using directories named ":param"
#   Example: router.d/r/:short_id/get.bash  matches any /r/XXXXXX
#   The captured value is automatically available as ROUTE_PARAMS[short_id]
# Multiple / mixed static+dynamic segments are fully supported:
#   router.d/users/:username/posts/:post_id/get.bash

declare -A ROUTE_PARAMS
export ROUTE_PARAMS
ROUTER_SCRIPT=""

_find_router_script() {
  local webpath="${WEBPATH}"
  local method="${METHOD}"
  local router_base="./router.d"

  # 1. Exact match (100% backward compatible)
  for ext in bash sh; do
    for variant in all "${method}"; do
      local _script="${router_base}${webpath}/${variant}.${ext}"
      [[ -f "${_script}" ]] && { ROUTER_SCRIPT="${_script}"; return 0; }
    done
  done

  # 2. Dynamic match using :param directories
  local -a segs
  IFS='/' read -r -a segs <<< "${webpath#/}"
  [[ "${#segs[@]}" -eq 0 || -z "${segs[0]}" ]] && segs=()

  local current_router="${router_base}"
  local i seg param_name

  for ((i=0; i<${#segs[@]}; i++)); do
    seg="${segs[i]}"

    # Try exact directory first
    local exact="${current_router}/${seg}"
    if [[ -d "${exact}" ]]; then
      current_router="${exact}"
      continue
    fi

    # Try any :param directory at this level
    local matched=0
    for d in "${current_router}"/*; do
      [[ -d "${d}" ]] || continue
      local dirname="${d##*/}"
      if [[ "${dirname}" == :* ]]; then
        param_name="${dirname#:}"
        [[ -n "${param_name}" ]] || continue
        ROUTE_PARAMS["${param_name}"]="${seg}"
        current_router="${d}"
        matched=1
        break
      fi
    done
    (( matched == 1 )) && continue

    # No match possible
    return 1
  done

  # 3. At the final router directory, look for handler file
  for ext in bash sh; do
    for variant in all "${method}"; do
      local _script="${current_router}/${variant}.${ext}"
      [[ -f "${_script}" ]] && { ROUTER_SCRIPT="${_script}"; return 0; }
    done
  done

  return 1
}

# Source the resolved router script (if any)
_find_router_script || true
if [[ -n "${ROUTER_SCRIPT:-}" ]]; then
  source "${ROUTER_SCRIPT}"
fi

if [[ -f "${ROOT}/${WEBPATH}/index.bash" ]]; then
  source "${ROOT}/${WEBPATH}/index.bash"
elif [[ -f "${ROOT}/${WEBPATH}/index.sh" ]]; then
  source "${ROOT}/${WEBPATH}/index.sh"
elif [[ -f "${FILE}" ]]; then
  if [[ "${FILE##*.}" =~ ^(bash|sh)$ ]] ; then
    source "${FILE}"
  else
    if [[ "${FILE##*.}" =~ ^(html|htm|xhtml|shtml)$ ]] ; then
      _ct="$(mime_type "${FILE}")"
      mkdir -p tmp
      _tempfile=$(mktemp tmp/tempfile-XXXXXX)
      cp -f "${FILE}" "${_tempfile}"
      # Execute code inside <? ... ?> and replace the block with the
      # command's stdout.
      # -0777 slurps whole file, s///gs allows multiline and non-greedy
      # match, e evaluates replacement.
      perl -0777 -pe '
      s{<\?(.+?)\?>}{
          do {
              my $cmd = $1;
              chomp $cmd;
              open my $fh, "-|", "bash", "-c", $cmd
                  or die "bash -c failed: $!";
              local $/;
              my $out = <$fh>;
              close $fh;
              $out =~ s/\r\z//;
              $out;
          }
      }egs
      ' "${_tempfile}" > "${_tempfile}.processed"
      mv -f "${_tempfile}.processed" "${_tempfile}"
      SIZE=$(stat -c%s "${_tempfile}" 2>/dev/null || wc -c <"${_tempfile}")
      HEADERS["content-type"]="${_ct}"
      HEADERS["content-length"]="${SIZE}"
      HEADERS["connection"]="close"
      print_status "200" "OK"
      print_headers
      print_crnl
      cat "${_tempfile}"
      rm -f "${_tempfile}"
      unset _tempfile
    else
      _ct="$(mime_type "${FILE}")"
      SIZE=$(stat -c%s "${FILE}" 2>/dev/null || wc -c <"${FILE}")
      HEADERS["content-type"]="${_ct}"
      HEADERS["content-length"]="${SIZE}"
      HEADERS["connection"]="close"
      print_status "200" "OK"
      print_headers
      print_crnl
      cat "${FILE}"
    fi
  fi
elif [[ -d "${ROOT}/${WEBPATH}" ]] ; then
  for _f in "${ROOT}/${WEBPATH}"/*.sh "${ROOT}/${WEBPATH}"/*.bash ; do
    [[ -f "${_f}" ]] || continue
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

exit 0

