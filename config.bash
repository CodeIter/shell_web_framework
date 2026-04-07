#!/usr/bin/env bash

set -euo pipefail

[[ -f .env ]] && source .env

export HOST=127.0.0.1
export PORT=8080

