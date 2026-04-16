#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$(realpath "$0")")" || exit

source config.bash

BASH_HOST="${BASH_HOST:-127.0.0.1}"
BASH_PORT="${BASH_PORT:-8080}"

if command -v socat 2>&1 >/dev/null ; then
  sh -xc "socat TCP-LISTEN:${BASH_PORT},bind=${BASH_HOST},reuseaddr,fork EXEC:./handler.bash"
elif command -v ncat 2>&1 >/dev/null ; then
  sh -xc "ncat -l -k ${BASH_HOST} ${BASH_PORT} --sh-exec ./handler.bash"
else
  >&2 echo "error: cannot create server: missing required utility (socat, ncat)"
  exit 1
fi

