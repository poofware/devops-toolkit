#!/usr/bin/env bash
set -e

# Optionally allow overriding the starting port via env var or command line:
NGROK_HOST_PORT="$1"

if [ -z "$NGROK_HOST_PORT" ]; then
  echo "[ERROR] ngrok host port is required." >&2
  echo "Usage: $0 <ngrok_host_port>" >&2
  exit 1
fi

echo "[INFO] Fetching ngrok tunnel URL..." >&2

# Poll for the ngrok public URL with a timeout of 30 seconds
timeout=30
while (( timeout > 0 )); do
  NGROK_URL=$(curl -s http://localhost:$NGROK_HOST_PORT/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
  if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    echo "$NGROK_URL"
    exit 0
  fi
  echo "[INFO] Waiting for ngrok tunnel to be available..." >&2
  sleep 1
  ((timeout--))
done

echo "[ERROR] ngrok tunnel did not become available in time." >&2
exit 1

