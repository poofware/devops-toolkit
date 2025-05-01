#!/usr/bin/env bash
#
# run_migrations.sh — LaunchDarkly-driven, isolated-schema capable
#
# Flow:
#   0. Validate essential env vars
#   1. Decrypt HCP_ENCRYPTED_API_TOKEN          (via encryption.sh)
#   2. Fetch DB_URL and LD_SDK_KEY              (via HCP)
#   3. Ask LaunchDarkly for `using_isolated_schema`
#   4. If flag is TRUE → build/ensure isolated schema
#   5. Wait for DB readiness
#   6. Run migrations
set -euo pipefail
IFS=$'\n\t'

###############################################################################
# 0. Required environment
###############################################################################
: "${HCP_ENCRYPTED_API_TOKEN:?HCP_ENCRYPTED_API_TOKEN env var is required}"

###############################################################################
# 1. Decrypt API token (for HCP)
###############################################################################
source ./encryption.sh                       # provides decrypt_token()
export HCP_API_TOKEN="$(decrypt_token "${HCP_ENCRYPTED_API_TOKEN}")"
echo "[INFO] HCP_API_TOKEN decrypted."

###############################################################################
# 2. Fetch DB_URL and LD_SDK_KEY secrets from HCP
###############################################################################
echo "[INFO] Fetching secrets from HCP…"

DB_URL="$(./fetch_hcp_secret_from_secrets_json.sh DB_URL      | jq -r '.DB_URL      // empty')"
LD_SDK_KEY="$(./fetch_hcp_secret_from_secrets_json.sh LD_SDK_KEY | jq -r '.LD_SDK_KEY // empty')"

if [[ -z "${DB_URL}"    || "${DB_URL}"    == "null" ]]; then
  echo "[ERROR] Could not retrieve 'DB_URL' from HCP." >&2
  exit 1
fi
if [[ -z "${LD_SDK_KEY}" || "${LD_SDK_KEY}" == "null" ]]; then
  echo "[ERROR] Could not retrieve 'LD_SDK_KEY' from HCP." >&2
  exit 1
fi
export LD_SDK_KEY
echo "[INFO] Secrets fetched."

###############################################################################
# 3. Evaluate LaunchDarkly flag
###############################################################################
echo "[INFO] Evaluating LaunchDarkly flag 'using_isolated_schema'…"
ISOLATED_FLAG="$(./fetch_launchdarkly_flag.sh using_isolated_schema \
                 | jq -r '.using_isolated_schema' | tr '[:upper:]' '[:lower:]')"

USE_ISOLATED_SCHEMA=false
[[ "${ISOLATED_FLAG}" == "true" ]] && USE_ISOLATED_SCHEMA=true

###############################################################################
# 4. Build / ensure isolated schema if flag is TRUE
###############################################################################
EFFECTIVE_DB_URL="${DB_URL}"   # default (shared schema)

if $USE_ISOLATED_SCHEMA; then
  echo "[INFO] Flag is TRUE – enabling isolated schema."

  : "${UNIQUE_RUNNER_ID:?UNIQUE_RUNNER_ID env var is required when isolation is enabled}"
  : "${UNIQUE_RUN_NUMBER:?UNIQUE_RUN_NUMBER env var is required when isolation is enabled}"

  ISOLATED_SCHEMA="$(echo "${UNIQUE_RUNNER_ID}-${UNIQUE_RUN_NUMBER}" \
                      | tr '[:upper:]' '[:lower:]')"

  # Append `search_path` param, preserving any existing query string
  if [[ "${DB_URL}" == *\?* ]]; then
    EFFECTIVE_DB_URL="${DB_URL}&search_path=${ISOLATED_SCHEMA}"
  else
    EFFECTIVE_DB_URL="${DB_URL}?search_path=${ISOLATED_SCHEMA}"
  fi

  echo "[INFO] Using isolated schema '${ISOLATED_SCHEMA}'."

  # Ensure schema exists (idempotent)
  echo "[INFO] Ensuring schema '${ISOLATED_SCHEMA}' exists…"
  psql "${DB_URL}" -v ON_ERROR_STOP=1 \
       -c "CREATE SCHEMA IF NOT EXISTS \"${ISOLATED_SCHEMA}\";" >/dev/null
else
  echo "[INFO] Flag is FALSE – running migrations against shared schema."
fi

###############################################################################
# 5. Wait for database readiness
###############################################################################
echo "[INFO] Waiting for database readiness…"
attempts=10
while ! pg_isready -d "${DB_URL}" -t 1 >/dev/null 2>&1 && (( attempts-- > 0 )); do
  echo "  …still starting, ${attempts} tries left"
  sleep 1
done
if (( attempts < 0 )); then
  echo "[ERROR] Failed to connect to DB after 10 attempts." >&2
  exit 1
fi

###############################################################################
# 6. Run migrations
###############################################################################
echo "[INFO] Running migrations…"
migrate -path migrations -database "${EFFECTIVE_DB_URL}" up
echo "[INFO] Migrations complete."

