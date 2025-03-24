#!/bin/bash
set -e

echo "[INFO] Starting stripe-webhook-test-entrypoint..."

: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"
: "${APP_URL:?APP_URL env var is required}"
: "${STRIPE_WEBHOOK_CHECK_ROUTE:?STRIPE_WEBHOOK_CHECK_ROUTE env var is required}"
: "${STRIPE_WEBHOOK_CHECK_EVENTS:?No test events were provided. Please set STRIPE_WEBHOOK_CHECK_EVENTS}"

# 1) Ensure the main service is healthy
n=10
while ! curl -sf "${APP_URL}/health" && [ $((n--)) -gt 0 ]; do
  echo "[INFO] Waiting for service health from ${APP_URL}..."
  sleep 2
done
if [ $n -le 0 ]; then
  echo "[ERROR] Service health endpoint ${APP_URL}/health not responding after 10 attempts."
  exit 1
fi
echo "[INFO] Service is healthy!"

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

# 4) Trigger each event in the list
EVENT_IDS=()
echo "[INFO] Triggering events: $STRIPE_WEBHOOK_CHECK_EVENTS"
for EVENT_TYPE in $STRIPE_WEBHOOK_CHECK_EVENTS; do
  echo "[INFO] Triggering Stripe event: $EVENT_TYPE with metadata 'generated_by=webhook_test'"
  TRIGGER_OUTPUT=$(stripe trigger "$EVENT_TYPE" \
    --add "${EVENT_TYPE%%.*}:metadata[generated_by]=webhook_test" \
    --format json \
    --api-key "$STRIPE_SECRET_KEY" || true)

  if [ -z "$TRIGGER_OUTPUT" ]; then
    echo "[ERROR] 'stripe trigger' command produced empty output for event: $EVENT_TYPE"
    exit 1
  fi

  # Attempt to parse the event ID with jq
  # If jq fails to parse valid JSON, we'll capture the error.
  set +e
  EVENT_ID=$(echo "$TRIGGER_OUTPUT" | jq -r '.id // empty' 2> /tmp/jq_error.log)
  JQ_EXIT_CODE=$?
  set -e

  if [ $JQ_EXIT_CODE -ne 0 ]; then
    echo "[ERROR] jq parse error while reading the trigger output for $EVENT_TYPE."
    echo "==== FULL TRIGGER OUTPUT ===="
    echo "$TRIGGER_OUTPUT"
    echo "==== END TRIGGER OUTPUT ===="
    echo "[ERROR] jq error was:"
    cat /tmp/jq_error.log
    exit 1
  fi

  if [ -z "$EVENT_ID" ] || [ "$EVENT_ID" = "null" ]; then
    echo "[ERROR] Could not parse 'id' from stripe trigger output for event $EVENT_TYPE."
    echo "==== FULL TRIGGER OUTPUT ===="
    echo "$TRIGGER_OUTPUT"
    echo "==== END TRIGGER OUTPUT ===="
    exit 1
  fi

  # Extract event ID using jq
  EVENT_ID=$(echo "$TRIGGER_OUTPUT" | jq -r '.id // empty')
  if [ -z "$EVENT_ID" ] || [ "$EVENT_ID" = "null" ]; then
    echo "[ERROR] Could not parse 'id' from stripe trigger output. Output:"
    echo "$TRIGGER_OUTPUT"
    exit 1
  fi

  echo "[INFO] Triggered test Stripe event $EVENT_TYPE with ID: $EVENT_ID"
  EVENT_IDS+=("$EVENT_ID")
done

# 5) Poll the check endpoint for each event ID
#    The route is e.g. /api/v1/account/stripe/webhook/test-events
#    We'll pass ?id=<EVENT_ID>
CHECK_URL="${APP_URL}${STRIPE_WEBHOOK_CHECK_ROUTE}"
echo "[INFO] Checking events at: $CHECK_URL"

for EVENT_ID in "${EVENT_IDS[@]}"; do
  attempts=10
  while [ $attempts -gt 0 ]; do
    # Example final URL: http://localhost:8080/api/v1/account/stripe/webhook/test-events?id=evt_123
    CHECK_URL_WITH_ARG="${CHECK_URL}?id=${EVENT_ID}"
    STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$CHECK_URL_WITH_ARG" || true)
    if [ "$STATUS" = "200" ]; then
      echo "[INFO] Webhook event $EVENT_ID was received successfully!"
      break
    fi

    echo "[INFO] Webhook event $EVENT_ID not found yet (HTTP $STATUS). Retrying..."
    attempts=$((attempts - 1))
    sleep 2
  done

  if [ $attempts -le 0 ]; then
    echo "[ERROR] Timed out waiting for webhook event $EVENT_ID to be recognized by the service."
    exit 1
  fi
done

echo "[INFO] All test events verified successfully."
exit 0

