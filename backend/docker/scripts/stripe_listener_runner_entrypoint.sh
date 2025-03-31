#!/bin/bash
set -e

: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"
: "${APP_URL_FROM_COMPOSE_NETWORK:?APP_URL_FROM_COMPOSE_NETWORK env var is required}"
: "${STRIPE_WEBHOOK_CONNECTED_EVENTS:?STRIPE_WEBHOOK_CONNECTED_EVENTS env var is required (comma-separated list of events)}"
: "${STRIPE_WEBHOOK_PLATFORM_EVENTS:?STRIPE_WEBHOOK_PLATFORM_EVENTS env var is required (comma-separated list of events)}"
: "${STRIPE_WEBHOOK_ROUTE:?STRIPE_WEBHOOK_ROUTE env var is required}"

FORWARD_TO_URL="${APP_URL_FROM_COMPOSE_NETWORK}${STRIPE_WEBHOOK_ROUTE}"

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

# Make sure there are some events to listen for
if [ -z "$STRIPE_WEBHOOK_PLATFORM_EVENTS" ] && [ -z "$STRIPE_WEBHOOK_CONNECTED_EVENTS" ]; then
  echo "[ERROR] No events specified in STRIPE_WEBHOOK_PLATFORM_EVENTS or STRIPE_WEBHOOK_CONNECTED_EVENTS."
  exit 1
fi

# Combine platform and connected events into a single string
export ALL_EVENTS="${STRIPE_WEBHOOK_PLATFORM_EVENTS},${STRIPE_WEBHOOK_CONNECTED_EVENTS}"

exec stripe listen -e "${ALL_EVENTS}" --forward-connect-to "${FORWARD_TO_URL}" --forward-to "${FORWARD_TO_URL}" --api-key "${STRIPE_SECRET_KEY}"

