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

