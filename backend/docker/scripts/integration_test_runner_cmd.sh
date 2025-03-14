#!/bin/bash
set -e

# If APP_URL is empty, attempt to decrypt the HCP token, fetch LD_SDK_KEY from HCP,
# and then use it to get the APP_URL from LaunchDarkly (via fetch_launchdarkly_flag.sh).
if [ -z "${APP_URL}" ]; then
  if [ -z "${HCP_TOKEN_ENC_KEY:-}" ]; then
    echo "[ERROR] HCP_TOKEN_ENC_KEY is not set! Required for decrypting the HCP token." >&2
    exit 1
  fi

  # Decrypt the HCP token (requires encryption.sh, which is already copied)
  source ./encryption.sh
  export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"
  echo "[INFO] Using decrypted HCP_API_TOKEN to fetch LD_SDK_KEY from HCP..."

  # Fetch the 'LD_SDK_KEY' secret from HCP
  # Expecting JSON like: {"LD_SDK_KEY":"sdk-XXXXXXX"}
  PAYLOAD="$(./fetch_hcp_secret.sh LD_SDK_KEY)"
  LD_SDK_KEY_VALUE="$(echo "$PAYLOAD" | jq -r '.LD_SDK_KEY // empty')"

  if [ -z "$LD_SDK_KEY_VALUE" ] || [ "$LD_SDK_KEY_VALUE" = "null" ]; then
    echo "[ERROR] Could not retrieve 'LD_SDK_KEY' from HCP." >&2
    echo "Full response from fetch_hcp_secret.sh was:" >&2
    echo "$PAYLOAD" >&2
    exit 1
  fi

  export LD_SDK_KEY="$LD_SDK_KEY_VALUE"
  echo "[INFO] Successfully fetched LD_SDK_KEY from HCP."

  # Now use fetch_launchdarkly_flag.sh to retrieve 'app_url' from LaunchDarkly
  # We expect JSON like: {"APP_URL":"https://my-app.example.com"}
  echo "[INFO] Using LD_SDK_KEY to fetch 'app_url' from LaunchDarkly..."
  FLAG_PAYLOAD="$(./fetch_launchdarkly_flag.sh app_url)"
  NEW_APP_URL="$(echo "$FLAG_PAYLOAD" | jq -r '.app_url // empty')"

  if [ -z "$NEW_APP_URL" ] || [ "$NEW_APP_URL" = "null" ]; then
    echo "[ERROR] Could not retrieve 'app_url' from LaunchDarkly." >&2
    echo "Full response from fetch_launchdarkly_flag.sh was:" >&2
    echo "$FLAG_PAYLOAD" >&2
    exit 1
  fi

  export APP_URL="$NEW_APP_URL"
  echo "[INFO] Successfully fetched 'app_url' from LaunchDarkly."
  echo "[INFO] Starting integration tests with APP_URL: $APP_URL"
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

