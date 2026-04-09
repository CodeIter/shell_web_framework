#!/usr/bin/env bash

set -euo pipefail

>&2 echo "$(date) ${REMOTE_ADDR} :${REMOTE_PORT} ${REMOTE_HOST} ${REMOTE_PROTO} ${METHOD} ${WEBPATH}"

