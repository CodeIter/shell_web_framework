#!/usr/bin/env bash

set -euo pipefail

username="${BODY[username]:-}"
password="${BODY[password]:-}"

if [[ "$username" == "admin" && "$password" == "1234" ]]; then
  body='{"status":"ok"}'
  status=200
  msg="Ok"

  session_new
  session_put "username" "$username"
  session_put "role" "admin"
  session_save
  set_session_cookie
else
  body='{"status":"fail"}'
  status=401
  msg="Unauthorized"
fi

print_response_json "${status}" "${msg}" "${body}"

exit 0

