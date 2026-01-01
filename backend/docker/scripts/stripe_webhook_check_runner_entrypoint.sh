#!/bin/bash
set -e

echo "[INFO] Starting stripe-webhook-check-entrypoint..."

: "${APP_URL_FROM_ANYWHERE:?APP_URL_FROM_ANYWHERE env var is required}"
: "${STRIPE_WEBHOOK_CHECK_ROUTE:?STRIPE_WEBHOOK_CHECK_ROUTE env var is required}"
: "${APP_NAME:?APP_NAME env var is required}"
: "${UNIQUE_RUN_NUMBER:?UNIQUE_RUN_NUMBER env var is required}"
: "${UNIQUE_RUNNER_ID:?UNIQUE_RUNNER_ID env var is required}"

# Optional: connect (default) or platform
CHECK_MODE="$(echo "${STRIPE_WEBHOOK_CHECK_MODE:-connect}" | tr '[:upper:]' '[:lower:]')"
if [ "$CHECK_MODE" = "connected" ]; then
  CHECK_MODE="connect"
fi
if [ "$CHECK_MODE" != "connect" ] && [ "$CHECK_MODE" != "platform" ]; then
  echo "[ERROR] Invalid STRIPE_WEBHOOK_CHECK_MODE: '$STRIPE_WEBHOOK_CHECK_MODE' (use 'connect' or 'platform')."
  exit 1
fi

EVENT_TYPE="payment_intent.created"

# 1) Wait for the service to be healthy
source ./health_check.sh

# 3) Fetch Stripe secret from BWS for CLI usage
STRIPE_SECRET_KEY="$(./fetch_bws_secret.sh STRIPE_SECRET_KEY | jq -r '.STRIPE_SECRET_KEY // empty')"

if [ -z "$STRIPE_SECRET_KEY" ] || [ "$STRIPE_SECRET_KEY" = "null" ]; then
  echo "[ERROR] Could not retrieve 'STRIPE_SECRET_KEY' from BWS."
  exit 1
fi
echo "[INFO] 'STRIPE_SECRET_KEY' fetched from BWS."

# 4) Set up a trap to ensure the connected account is always deleted (connect mode only)
ACCOUNT_ID=""
cleanup() {
  if [ -n "$ACCOUNT_ID" ]; then
    echo "[INFO] Deleting connected account ID: $ACCOUNT_ID"
    stripe accounts delete "$ACCOUNT_ID" \
      --api-key "$STRIPE_SECRET_KEY" -c || true
  fi
}
trap cleanup EXIT

# 5) Create a connected account (connect mode only)
if [ "$CHECK_MODE" = "connect" ]; then
  echo "[INFO] Creating an Express connected account..."
  ACCOUNT_CREATE_OUTPUT="$(stripe accounts create --type=express --api-key "$STRIPE_SECRET_KEY")"
  if [ -z "$ACCOUNT_CREATE_OUTPUT" ]; then
    echo "[ERROR] Failed to create a connected account."
    exit 1
  fi

  ACCOUNT_ID="$(echo "$ACCOUNT_CREATE_OUTPUT" | jq -r '.id // empty')"
  if [ -z "$ACCOUNT_ID" ]; then
    echo "[ERROR] Could not parse 'id' from connected account creation response."
    echo "==== RAW CREATE OUTPUT ===="
    echo "$ACCOUNT_CREATE_OUTPUT"
    exit 1
  fi
  echo "[INFO] Created connected account: $ACCOUNT_ID"
else
  echo "[INFO] Running in platform mode; skipping connected account creation."
fi

# 6) Trigger a Stripe event with metadata
METADATA_VALUE="webhook_check-${APP_NAME}-${UNIQUE_RUNNER_ID}-${UNIQUE_RUN_NUMBER}"
if [ "$CHECK_MODE" = "connect" ]; then
  echo "[INFO] Triggering Stripe event: ${EVENT_TYPE} (connected account: $ACCOUNT_ID)"
else
  echo "[INFO] Triggering Stripe event: ${EVENT_TYPE} (platform account)"
fi
echo "[INFO] Using metadata 'generated_by=${METADATA_VALUE}'"

ACCOUNT_ARGS=()
if [ "$CHECK_MODE" = "connect" ]; then
  ACCOUNT_ARGS=(--stripe-account "$ACCOUNT_ID")
fi

set +e
TRIGGER_OUTPUT=$(timeout 15s stripe trigger "${EVENT_TYPE}" \
  "${ACCOUNT_ARGS[@]}" \
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

# 7) Get the single most recent matching event
if [ "$CHECK_MODE" = "connect" ]; then
  echo "[INFO] Fetching the last event from Stripe (connected account: $ACCOUNT_ID)..."
else
  echo "[INFO] Fetching the last event from Stripe (platform account)..."
fi
set +e
EVENTS_JSON=$(stripe events list \
  --limit 3 \
  "${ACCOUNT_ARGS[@]}" \
  --api-key "$STRIPE_SECRET_KEY" 2>&1)
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

# 8) Parse the event ID
EVENT_ID=$(echo "$EVENTS_JSON" | jq -r --arg event_type "$EVENT_TYPE" --arg generated_by "$METADATA_VALUE" '
  .data[]
  | select(.type == $event_type)
  | select(.data.object.metadata.generated_by == $generated_by)
  | .id // empty
' | head -n 1)

if [ -z "$EVENT_ID" ]; then
  EVENT_ID=$(echo "$EVENTS_JSON" | jq -r --arg event_type "$EVENT_TYPE" '
    .data[] | select(.type == $event_type) | .id // empty
  ' | head -n 1)
fi
if [ -z "$EVENT_ID" ]; then
  echo "[ERROR] Could not parse an event id from the last event."
  echo "==== RAW EVENTS JSON ===="
  echo "$EVENTS_JSON"
  exit 1
fi
echo "[INFO] Found triggered event ID: $EVENT_ID"

# 9) Poll the check endpoint to ensure the event was received by your app
CHECK_URL="${APP_URL_FROM_ANYWHERE}${STRIPE_WEBHOOK_CHECK_ROUTE}"
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
