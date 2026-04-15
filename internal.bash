#!/usr/bin/env bash

set -euo pipefail

# helper: pick first non-empty
_pick() {
  local _v
  for _v in "${@}" ; do
    [[ -n "$_v" ]] && { printf '%s' "${_v}" ; return 0 ; }
  done
  return 1
}

_trim_cr() {
  local s="$1"
  printf '%s' "${s%$'\r'}"
}

_ensure_upload_dir() {
  mkdir -p "${UPLOAD_DIR}"
}

_sanitize_upload_filename() {
  local name="$1"
  name="${name##*/}"
  name="${name##*\\}"
  name="${name//[^A-Za-z0-9._-]/_}"
  [[ -n "$name" ]] || name="upload"
  printf '%s' "$name"
}

_multipart_finalize_part() {
  local field="$1"
  local filename="$2"
  local content_type="$3"
  local tmpfile="$4"
  local value="$5"

  [[ -n "$field" ]] || return 0

  if [[ -n "$filename" ]]; then
    # File upload: only move an existing temp file once.
    # If the part was already finalized, tmpfile will be gone.
    [[ -n "$tmpfile" && -f "$tmpfile" ]] || return 0

    local size safe_name dest
    size=$(stat -c%s "$tmpfile" 2>/dev/null || wc -c <"$tmpfile")
    (( size <= UPLOAD_MAX_SIZE )) || {
      rm -f "$tmpfile"
      return 1
    }

    _ensure_upload_dir
    safe_name="$(_sanitize_upload_filename "$filename")"
    dest="${UPLOAD_DIR%/}/$(date +%s)-$$-$(rand_hex)-${safe_name}"
    mv -f "$tmpfile" "$dest"

    UPLOAD_PATH["$field"]="$dest"
    UPLOAD_NAME["$field"]="$filename"
    UPLOAD_TYPE["$field"]="${content_type:-application/octet-stream}"
    UPLOAD_SIZE["$field"]="$size"
  else
    BODY["$field"]="$value"
  fi
}

_parse_multipart_form() {
  local body_file="$1"
  local boundary="$2"
  local boundary_line="--${boundary}"
  local closing_line="--${boundary}--"
  local line state="headers"
  local field="" filename="" content_type="" value="" tmpfile=""
  local committed=0
  local re_cd re_ct

  re_cd='^Content-Disposition:[[:space:]]*form-data;[[:space:]]*name="([^"]+)"(;[[:space:]]*filename="([^"]*)")?'
  re_ct='^Content-Type:[[:space:]]*(.+)$'

  _multipart_commit() {
    local -n _done="$1"
    shift
    ((_done == 0)) || return 0
    _done=1
    _multipart_finalize_part "$@"
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(_trim_cr "$line")"

    if [[ "$line" == "$boundary_line" ]]; then
      if [[ -n "$field" ]]; then
        _multipart_commit committed "$field" "$filename" "$content_type" "$tmpfile" "$value"
      fi
      field="" ; filename="" ; content_type="" ; value="" ; tmpfile="" ; committed=0 ; state="headers"
      continue
    fi

    if [[ "$line" == "$closing_line" ]]; then
      if [[ -n "$field" ]]; then
        _multipart_commit committed "$field" "$filename" "$content_type" "$tmpfile" "$value"
      fi
      break
    fi

    if [[ "$state" == "headers" ]]; then
      if [[ -z "$line" ]]; then
        state="body"
        if [[ -n "$filename" ]]; then
          _ensure_upload_dir
          tmpfile="$(mktemp "${UPLOAD_DIR%/}/.upload.XXXXXX")"
        fi
        continue
      fi

      if [[ "$line" =~ $re_cd ]]; then
        field="${BASH_REMATCH[1]}"
        filename="${BASH_REMATCH[3]:-}"
        continue
      fi

      if [[ "$line" =~ $re_ct ]]; then
        content_type="${BASH_REMATCH[1]}"
        continue
      fi

      continue
    fi

    if [[ -n "$filename" ]]; then
      printf '%s\n' "$line" >> "$tmpfile"
    else
      if [[ -z "$value" ]]; then
        value="$line"
      else
        value+=$'\n'"$line"
      fi
    fi
  done < "$body_file"

  if [[ -n "$field" ]]; then
    _multipart_commit committed "$field" "$filename" "$content_type" "$tmpfile" "$value"
  fi
}

