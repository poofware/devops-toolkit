#!/usr/bin/env bash
set -euo pipefail        # make -e apply to every element of a pipeline

trap 'echo; echo "[INFO] Interrupted - exiting."; exit 130' INT  # honour Ctrl-C

CLOUDFLARED_CONTAINER=${1:-}
if [[ -z $CLOUDFLARED_CONTAINER ]]; then
  echo "[ERROR] cloudflared container name or id is required." >&2
  echo "Usage: $0 <cloudflared_container>" >&2
  exit 1
fi

echo "[INFO] Fetching cloudflared tunnel URL..." >&2

if [[ -n ${CLOUDFLARED_HOSTNAME:-} ]]; then
  echo "https://${CLOUDFLARED_HOSTNAME}"
  exit 0
fi

while :; do
  if CLOUDFLARED_URL=$(docker logs --tail 200 "${CLOUDFLARED_CONTAINER}" 2>&1 \
                         | grep -Eo 'https?://[A-Za-z0-9.-]+\\.trycloudflare\\.com' \
                         | tail -1); then
    if [[ -n $CLOUDFLARED_URL ]]; then
      echo "$CLOUDFLARED_URL"
      exit 0
    fi
  fi

  echo "[INFO] Waiting for cloudflared tunnel to be available..." >&2
  sleep 1        # SIGINT during this sleep now ends the script
done
