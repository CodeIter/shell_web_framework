#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$(realpath "$0")")" || exit

source config.bash

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"

if command -v socat 2>&1 >/dev/null ; then
  sh -xc "socat TCP-LISTEN:${PORT},bind=${HOST},reuseaddr,fork EXEC:./handler.bash"
elif command -v ncat 2>&1 >/dev/null ; then
  sh -xc "ncat -l -k ${HOST} ${PORT} --sh-exec ./handler.bash"
else
  >&2 echo "error: cannot create server: missing required utility (socat, ncat, or nc)"
  exit 1
fi

