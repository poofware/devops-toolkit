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
: "${DATABASE_URL_SECRET_NAME:?DATABASE_URL_SECRET_NAME env var is required}"

# Source the encryption script to get `decrypt_token` function
source ./encryption.sh

# Decrypt the token
export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"

echo "[INFO] [Migrate Container] Using decrypted HCP_API_TOKEN to fetch DB_URL..."

# Now fetch the single secret for the DB URL
SECRET_JSON="$(./fetch_hcp_secret.sh "${DATABASE_URL_SECRET_NAME}")"

# Extract the DB URL from the JSON
DB_URL="$(echo "$SECRET_JSON" | jq -r ".[\"$DATABASE_URL_SECRET_NAME\"]")"
if [ -z "$DB_URL" ]; then
  echo "[ERROR] [Migrate Container] Could not retrieve the secret '${DATABASE_URL_SECRET_NAME}'"
  echo "Full response was:"
  echo "$SECRET_JSON"
  exit 1
fi

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

