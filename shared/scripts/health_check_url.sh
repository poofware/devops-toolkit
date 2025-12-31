#!/usr/bin/env bash
#
# Simple health check with retries.
#
# Usage:
#   health_check_url.sh <url> [retries] [timeout_seconds] [interval_seconds]
#
set -euo pipefail

URL="${1:-}"
RETRIES="${2:-20}"
TIMEOUT="${3:-5}"
INTERVAL="${4:-3}"

if [[ -z "$URL" ]]; then
  echo "[ERROR] Usage: health_check_url.sh <url> [retries] [timeout_seconds] [interval_seconds]" >&2
  exit 1
fi

for ((i=1; i<=RETRIES; i++)); do
  if curl -fsS --max-time "$TIMEOUT" "$URL" >/dev/null; then
    echo "[INFO] Health check passed: $URL"
    exit 0
  fi
  echo "[WARN] Health check failed ($i/$RETRIES): $URL"
  sleep "$INTERVAL"
done

echo "[ERROR] Health check failed after $RETRIES attempts: $URL" >&2
exit 1
