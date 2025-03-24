#!/bin/bash
set -e

echo "[INFO] Starting stripe-webhook-check-entrypoint..."

: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"
: "${APP_URL:?APP_URL env var is required}"
: "${STRIPE_WEBHOOK_CHECK_ROUTE:?STRIPE_WEBHOOK_CHECK_ROUTE env var is required}"
: "${APP_NAME:?APP_NAME env var is required}"
: "${UNIQUE_RUN_NUMBER:?UNIQUE_RUN_NUMBER env var is required}"
: "${UNIQUE_RUNNER_ID:?UNIQUE_RUNNER_ID env var is required}"

# 1) Wait for the service to be healthy
source ./health_check.sh

# 2) Decrypt the HCP token if needed
source ./encryption.sh
export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"
echo "[INFO] Decrypted HCP_API_TOKEN successfully."

# 3) Fetch Stripe secret from HCP for CLI usage
PAYLOAD="$(./fetch_hcp_secret.sh STRIPE_SECRET_KEY)"
STRIPE_SECRET_KEY="$(echo "$PAYLOAD" | jq -r '.STRIPE_SECRET_KEY // empty')"
if [ -z "$STRIPE_SECRET_KEY" ] || [ "$STRIPE_SECRET_KEY" = "null" ]; then
  echo "[ERROR] Could not retrieve 'STRIPE_SECRET_KEY' from HCP."
  echo "Full response from fetch_hcp_secret.sh was:"
  echo "$PAYLOAD"
  exit 1
fi
echo "[INFO] 'STRIPE_SECRET_KEY' fetched from HCP."

# 4) Trigger a single 'payment_intent.created' event with identifying metadata
echo "[INFO] Triggering Stripe event: payment_intent.created"
METADATA_VALUE="webhook_check-${APP_NAME}-${UNIQUE_RUNNER_ID}-${UNIQUE_RUN_NUMBER}"
echo "[INFO] Using metadata 'generated_by=${METADATA_VALUE}'"

set +e
TRIGGER_OUTPUT=$(timeout 15s stripe trigger payment_intent.created \
  --add "payment_intent:metadata.generated_by=${METADATA_VALUE}" \
  --api-key "$STRIPE_SECRET_KEY" 2>&1)
TRIGGER_EXIT=$?
set -e

if [ $TRIGGER_EXIT -ne 0 ]; then
  echo "[ERROR] 'stripe trigger payment_intent.created' command failed or timed out (exit code: $TRIGGER_EXIT)."
  echo "==== FULL TRIGGER OUTPUT ===="
  echo "$TRIGGER_OUTPUT"
  echo "==== END TRIGGER OUTPUT ===="
  exit 1
fi

if [ -z "$TRIGGER_OUTPUT" ]; then
  echo "[WARN] 'stripe trigger' returned empty output for payment_intent.created."
fi

# Allow a brief pause so Stripe can register the event
sleep 2

# 4.1) Look up the most recent 10 events and find the one we just triggered
echo "[INFO] Fetching the last 10 events from Stripe..."
set +e
EVENTS_JSON=$(stripe events list --limit 10 --api-key "$STRIPE_SECRET_KEY" 2>&1)
EVENTS_EXIT=$?
set -e

if [ $EVENTS_EXIT -ne 0 ]; then
  echo "[ERROR] 'stripe events list' command failed (exit code: $EVENTS_EXIT)."
  echo "==== FULL EVENTS OUTPUT ===="
  echo "$EVENTS_JSON"
  echo "==== END EVENTS OUTPUT ===="
  exit 1
fi

if [ -z "$EVENTS_JSON" ]; then
  echo "[ERROR] 'stripe events list' returned no data."
  exit 1
fi

# Attempt to parse JSON and find matching event
echo "[DEBUG] Parsing events for matching metadata: ${METADATA_VALUE}"
EVENT_ID=$(echo "$EVENTS_JSON" | jq -r \
  --arg SEARCH "$METADATA_VALUE" '
    .data
    | map(select(
        .type == "payment_intent.created" and
        .data.object.metadata.generated_by == $SEARCH
      ))
    | first
    | .id // ""
  ' 2>/tmp/stripe_jq_err.log)

# Check if jq had any parsing errors
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to parse Stripe events JSON using jq."
  echo "==== RAW EVENTS JSON ===="
  echo "$EVENTS_JSON"
  echo "==== jq stderr ===="
  cat /tmp/stripe_jq_err.log
  echo "==== END ERROR LOGS ===="
  exit 1
fi

if [ -z "$EVENT_ID" ]; then
  echo "[ERROR] Could not find a 'payment_intent.created' event in the last 10 events with metadata 'generated_by=${METADATA_VALUE}'."
  echo "==== RAW EVENTS JSON (truncated) ===="
  echo "$EVENTS_JSON"
  exit 1
fi

echo "[INFO] Found triggered event ID: $EVENT_ID"

# 5) Poll the check endpoint to ensure the event was received
CHECK_URL="${APP_URL}${STRIPE_WEBHOOK_CHECK_ROUTE}"
CHECK_URL_WITH_ARG="${CHECK_URL}?id=${EVENT_ID}"
echo "[INFO] Checking event at: $CHECK_URL_WITH_ARG"

attempts=10
while [ $attempts -gt 0 ]; do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$CHECK_URL_WITH_ARG" || true)
  if [ "$STATUS" = "200" ]; then
    echo "[INFO] Webhook event $EVENT_ID was received successfully!"
    echo "[INFO] Webhook check completed successfully."
    exit 0
  fi

  echo "[INFO] Webhook event $EVENT_ID not found yet (HTTP $STATUS). Retrying..."
  attempts=$((attempts - 1))
  sleep 2
done

echo "[ERROR] Timed out waiting for webhook event $EVENT_ID to be recognized by the service."
exit 1

