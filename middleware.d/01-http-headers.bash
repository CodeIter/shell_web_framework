#!/usr/bin/env bash

set -euo pipefail

HEADERS["x-powered-by"]="bash ${BASH_VERSION}"

HEADERS["strict-transport-security"]="max-age=63072000; includeSubDomains; preload"

HEADERS["x-content-type-options"]="nosniff"

HEADERS["permissions-policy"]="geolocation=(), microphone=(), camera=()"

HEADERS["content-security-policy"]="default-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"

HEADERS["referrer-policy"]="no-referrer"

HEADERS["x-frame-options"]="DENY"

# optional CORS header (enable only if needed)
# HEADERS["access-control-allow-origin"]="https://example.com"

