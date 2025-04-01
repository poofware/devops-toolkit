#!/usr/bin/env bash
set -e

echo "Waiting for ngrok tunnel to be available..." >&2

# Poll for the ngrok public URL with a timeout of 30 seconds
timeout=30
while (( timeout > 0 )); do
  NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
  if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    echo "$NGROK_URL"
    exit 0
  fi
  echo "Waiting for ngrok tunnel to be available..." >&2
  sleep 1
  ((timeout--))
done

echo "Error: ngrok tunnel did not become available in time." >&2
exit 1

