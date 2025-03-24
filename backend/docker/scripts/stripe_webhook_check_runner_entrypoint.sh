#!/bin/bash
set -e

echo "[INFO] Starting stripe-webhook-check-entrypoint..."

: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"
: "${APP_URL:?APP_URL env var is required}"
: "${STRIPE_WEBHOOK_EVENTS:?STRIPE_WEBHOOK_EVENTS env var is required (comma-separated list of events)}"
: "${STRIPE_WEBHOOK_CHECK_ROUTE:?STRIPE_WEBHOOK_CHECK_ROUTE env var is required}"
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

# 4) Trigger each event in the list
EVENT_IDS=()
echo "[INFO] Triggering events: $STRIPE_WEBHOOK_EVENTS"

for EVENT_TYPE in $(echo "$STRIPE_WEBHOOK_EVENTS" | tr ',' ' '); do
  echo "[INFO] Triggering Stripe event: $EVENT_TYPE with metadata 'generated_by=webhook_check'"

  # Use a timeout of 15s so we don't hang indefinitely
  set +e
  TRIGGER_OUTPUT=$(timeout 15s stripe trigger "$EVENT_TYPE" \
    --add "${EVENT_TYPE%%.*}:metadata.generated_by=webhook_check-${UNIQUE_RUNNER_ID}-${UNIQUE_RUN_NUMBER}" \
    --api-key "$STRIPE_SECRET_KEY" 2>&1)
  CMD_EXIT=$?
  set -e

  if [ $CMD_EXIT -ne 0 ]; then
    echo "[WARN] 'stripe trigger' command failed or timed out for event '$EVENT_TYPE' (exit code: $CMD_EXIT). Skipping..."
    echo "==== FULL TRIGGER OUTPUT ===="
    echo "$TRIGGER_OUTPUT"
    echo "==== END TRIGGER OUTPUT ===="
    continue
  fi

  if [ -z "$TRIGGER_OUTPUT" ]; then
    echo "[WARN] 'stripe trigger' returned empty output for event '$EVENT_TYPE'. Skipping..."
    continue
  fi

  set +e
  EVENT_ID=$(echo "$TRIGGER_OUTPUT" | grep -oE 'evt_[A-Za-z0-9]+' 2> /tmp/grep_err.log)
  GREP_EXIT_CODE=$?
  set -e

  echo "[DEBUG] grep exit code: $GREP_EXIT_CODE"

  if [ $GREP_EXIT_CODE -ne 0 ] || [ -z "$EVENT_ID" ]; then
    echo "[WARN] Could not parse an 'evt_' ID in the CLI output for '$EVENT_TYPE'. Likely not supported."
    echo "==== FULL TRIGGER OUTPUT ===="
    echo "$TRIGGER_OUTPUT"
    echo "==== END TRIGGER OUTPUT ===="
    echo "[DEBUG] grep stderr was:"
    cat /tmp/grep_err.log
    continue
  fi

  echo "[INFO] Triggered Stripe event '$EVENT_TYPE' with ID: $EVENT_ID"
  EVENT_IDS+=("$EVENT_ID")
done

# If no events were triggered successfully, fail early
if [ "${#EVENT_IDS[@]}" -eq 0 ]; then
  echo "[ERROR] None of the '$STRIPE_WEBHOOK_EVENTS' events could be triggered successfully."
  exit 1
fi

# 5) Poll the check endpoint for each event ID
CHECK_URL="${APP_URL}${STRIPE_WEBHOOK_CHECK_ROUTE}"
echo "[INFO] Checking events at: $CHECK_URL"

# We'll track how many events are recognized
RECOGNIZED_COUNT=0

for EVENT_ID in "${EVENT_IDS[@]}"; do
  attempts=10
  recognized=0

  while [ $attempts -gt 0 ]; do
    CHECK_URL_WITH_ARG="${CHECK_URL}?id=${EVENT_ID}"
    STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$CHECK_URL_WITH_ARG" || true)
    if [ "$STATUS" = "200" ]; then
      echo "[INFO] Webhook event $EVENT_ID was received successfully!"
      recognized=1
      break
    fi

    echo "[INFO] Webhook event $EVENT_ID not found yet (HTTP $STATUS). Retrying..."
    attempts=$((attempts - 1))
    sleep 2
  done

  if [ $recognized -eq 1 ]; then
    RECOGNIZED_COUNT=$((RECOGNIZED_COUNT + 1))
  else
    echo "[WARN] Timed out waiting for webhook event $EVENT_ID to be recognized by the service. Skipping..."
  fi
done

# If none were recognized, fail; otherwise succeed
if [ "$RECOGNIZED_COUNT" -eq 0 ]; then
  echo "[ERROR] None of the triggered events were successfully recognized by the service!"
  exit 1
fi

echo "[INFO] At least one event was verified successfully."
exit 0

