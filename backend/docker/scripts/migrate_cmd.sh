#!/usr/bin/env bash
#
# run_migrations.sh
#
# 1. Decrypt HCP_ENCRYPTED_API_TOKEN using encryption.sh
# 2. Fetch the DB URL secret from HCP
# 3. Wait for DB readiness
# 4. Run migrations

set -e

: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"

# Source the encryption script to get `decrypt_token` function
source ./encryption.sh

# Decrypt the token
export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"
echo "[INFO] [Migrate Container] Using decrypted HCP_API_TOKEN to fetch 'DB_URL' from HCP..."

# Now fetch the single secret for the DB URL
PAYLOAD="$(./fetch_hcp_secret.sh DB_URL)"
DB_URL="$(echo "$PAYLOAD" | jq -r '.DB_URL // empty')"

if [ -z "$DB_URL" ] || [ "$DB_URL" = "null" ]; then
  echo "[ERROR] Could not retrieve 'DB_URL' from HCP."
  echo "Full response from fetch_hcp_secret.sh was:"
  echo "$PAYLOAD"
  exit 1
fi

echo "[INFO] Successfully fetched 'DB_URL' from HCP."

echo "[INFO] [Migrate Container] Checking database readiness..."
n=10
while ! pg_isready -d "$DB_URL" -t 1 >/dev/null 2>&1 && [ $((n--)) -gt 0 ]; do
  echo "  Waiting for DB to become ready..."
  sleep 1
done

if [ $n -le 0 ]; then
  echo "[ERROR] [Migrate Container] Failed to connect to DB after 10 attempts."
  exit 1
fi

echo "[INFO] [Migrate Container] Running migrations..."
migrate -path migrations -database "$DB_URL" up

