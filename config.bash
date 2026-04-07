#!/usr/bin/env bash

set -euo pipefail

[[ -f .env ]] && source .env

export HOST=127.0.0.1
export PORT=8080

export SESSION_DIR="${SESSION_DIR:-${PWD}/sessions}"
export SESSION_SECRET="${SESSION_SECRET:-change-this-secret-in-env}"
export SESSION_TTL="${SESSION_TTL:-86400}"   # 1 day

