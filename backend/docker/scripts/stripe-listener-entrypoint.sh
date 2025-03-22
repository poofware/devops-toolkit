#!/bin/bash
set -e

: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"
: "${FORWARD_TO_URL:?FORWARD_TO_URL env var is required}"

echo "[INFO] Starting Stripe listener with forward-to: ${FORWARD_TO_URL}"

# Source encryption script to get decrypt_token function
source ./encryption.sh

# Decrypt the HCP API token
export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"
echo "[INFO] Using decrypted HCP_API_TOKEN to fetch 'STRIPE_SECRET_KEY' from HCP..."

# Fetch the Stripe secret key from HCP
# Note that fetch_hcp_secret.sh typically uses $HCP_APP_NAME, $HCP_ORG_ID, $HCP_PROJECT_ID, etc.
PAYLOAD="$(./fetch_hcp_secret.sh STRIPE_SECRET_KEY)"
STRIPE_SECRET_KEY="$(echo "$PAYLOAD" | jq -r '.STRIPE_SECRET_KEY // empty')"

if [ -z "$STRIPE_SECRET_KEY" ] || [ "$STRIPE_SECRET_KEY" = "null" ]; then
  echo "[ERROR] Could not retrieve 'STRIPE_SECRET_KEY' from HCP."
  echo "Full response from fetch_hcp_secret.sh was:"
  echo "$PAYLOAD"
  exit 1
fi

echo "[INFO] Successfully fetched 'STRIPE_SECRET_KEY' from HCP."
echo "[INFO] Starting 'stripe listen --forward-to ${FORWARD_TO_URL}' with the provided secret key."

exec stripe listen --forward-to "${FORWARD_TO_URL}" --api-key "${STRIPE_SECRET_KEY}"

