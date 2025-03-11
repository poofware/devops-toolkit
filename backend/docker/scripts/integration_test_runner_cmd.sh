#!/bin/bash
set -e

# If APP_URL is empty, attempt to decrypt the HCP token and fetch APP_URL from HCP
if [ -z "${APP_URL}" ]; then
  if [ -z "${HCP_TOKEN_ENC_KEY:-}" ]; then
    echo "[ERROR] HCP_TOKEN_ENC_KEY is not set! Required for decrypting the HCP token." >&2
    exit 1
  fi

  # Decrypt the HCP token (requires encryption.sh, which is already copied)
  source ./encryption.sh
  export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"
  echo "[INFO] Using decrypted HCP_API_TOKEN to fetch APP_URL..."

  # Fetch the 'APP_URL' secret from HCP using fetch_hcp_secret.sh
  # It outputs a JSON like: {"APP_URL":"https://my-app.example.com"}
  PAYLOAD="$(./fetch_hcp_secret.sh APP_URL)"
  NEW_APP_URL="$(echo "$PAYLOAD" | jq -r '.APP_URL // empty')"

  if [ -z "$NEW_APP_URL" ] || [ "$NEW_APP_URL" = "null" ]; then
    echo "[ERROR] Could not retrieve 'APP_URL' secret from HCP." >&2
    echo "Full response from fetch_hcp_secret.sh was:" >&2
    echo "$PAYLOAD" >&2
    exit 1
  fi

  export APP_URL="$NEW_APP_URL"
  echo "[INFO] Successfully fetched APP_URL: $APP_URL"
else
  echo "[INFO] Using provided APP_URL: $APP_URL"
fi

# Health check loop: tries up to 10 times to confirm the service is up
n=10
while ! curl -sf "$APP_URL/health" && [ $((n--)) -gt 0 ]; do
  echo "Waiting for service health from $APP_URL..."
  sleep 2
done

if [ $n -le 0 ]; then
  echo "[ERROR] Failed to connect after 10 attempts." >&2
  exit 1
fi

# Finally, run the integration tests
exec ./integration_test -test.v

