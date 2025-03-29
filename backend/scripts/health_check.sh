#!/bin/bash
set -e

: "${COMPOSE_NETWORK_APP_URL:?COMPOSE_NETWORK_APP_URL env var is required}"

# Health check loop: tries up to 10 times to confirm the service is up
n=10
while ! curl -sf "$COMPOSE_NETWORK_APP_URL/health" && [ $((n--)) -gt 0 ]; do
  echo "Waiting for service health from $COMPOSE_NETWORK_APP_URL..."
  sleep 2
done

if [ $n -le 0 ]; then
  echo "[ERROR] Failed to connect after 10 attempts." >&2
  exit 1
fi

echo "[INFO] Service is healthy!"
