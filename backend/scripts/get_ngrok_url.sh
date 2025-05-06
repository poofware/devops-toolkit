#!/usr/bin/env bash
set -e

NGROK_HOST_PORT="$1"

if [ -z "$NGROK_HOST_PORT" ]; then
  echo "[ERROR] ngrok host port is required." >&2
  echo "Usage: $0 <ngrok_host_port>" >&2
  exit 1
fi

echo "[INFO] Fetching ngrok tunnel URL..." >&2

# Loop until ngrok responds with a non-null public_url
while true; do
  NGROK_URL=$(curl -s http://localhost:$NGROK_HOST_PORT/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
  if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    echo "$NGROK_URL"
    exit 0
  fi

  echo "[INFO] Waiting for ngrok tunnel to be available…" >&2
  sleep 1
done
