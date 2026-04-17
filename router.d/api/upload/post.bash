#!/usr/bin/env bash

set -euo pipefail

file_path="${UPLOAD_PATH[file]:-}"
file_name="${UPLOAD_NAME[file]:-}"
file_size="${UPLOAD_SIZE[file]:-0}"
mime_type="${UPLOAD_TYPE[file]:-}"

if [[ -z "$file_path" ]]; then
  rm -f "${file_path}"
  print_response_json "400" "Bad Request" '{"error":"missing file field named file"}'
  exit 0
fi

body='{"ok":true,"name":"'"$file_name"'","size":"'"$file_size"'","type":"'"$mime_type"'","path":"'"$file_path"'"}'

rm -f "${file_path}"

print_response_json "200" "OK" "$body"

exit 0

