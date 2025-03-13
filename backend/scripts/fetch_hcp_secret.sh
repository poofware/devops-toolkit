#!/usr/bin/env bash
#
# Usage:
#   ./fetch_hcp_secret.sh [SECRET_NAME]
#
# If SECRET_NAME is provided, fetch only that one secret.
# Otherwise, fetch all secrets for the specified app.
#
# Environment variables required:
#   HCP_API_TOKEN  - The API token to authenticate against HCP.
#   HCP_ORG_ID     - The HCP organization ID.
#   HCP_PROJECT_ID - The HCP project ID.
#   APP_NAME       - The base application name (e.g., "auth-service").
#   ENV            - The environment (e.g., "dev", "staging", "prod").

set -e

SECRET_NAME="$1"

# Basic checks for required environment variables
: "${HCP_API_TOKEN:?HCP_API_TOKEN env var is required}"
: "${HCP_ORG_ID:?HCP_ORG_ID env var is required}"
: "${HCP_PROJECT_ID:?HCP_PROJECT_ID env var is required}"
: "${HCP_APP_NAME:?HCP_APP_NAME env var is required}"

# Determine the URL for single secret vs all secrets
if [ -n "$SECRET_NAME" ]; then
  # Fetch one secret
  URL="https://api.cloud.hashicorp.com/secrets/2023-11-28/organizations/${HCP_ORG_ID}/projects/${HCP_PROJECT_ID}/apps/${HCP_APP_NAME}/secrets/${SECRET_NAME}:open"
else
  # Fetch all secrets
  URL="https://api.cloud.hashicorp.com/secrets/2023-11-28/organizations/${HCP_ORG_ID}/projects/${HCP_PROJECT_ID}/apps/${HCP_APP_NAME}/secrets:open"
fi

# Perform the API request
RESPONSE="$(curl --silent --show-error --location \
  "$URL" \
  --header "Authorization: Bearer ${HCP_API_TOKEN}")"

if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to make request to HCP." >&2
  echo "Full response from HCP was:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

# If a single secret is requested, parse just that secret value;
# otherwise, parse all secrets into a JSON object of { "name": "value" }.
if [ -n "$SECRET_NAME" ]; then
  SECRET_VALUE="$(echo "$RESPONSE" | jq -r '.secret.static_version.value // empty')"
  if [ -z "$SECRET_VALUE" ]; then
    echo "[ERROR] Could not retrieve the secret '$SECRET_NAME' for app '$HCP_APP_NAME'." >&2
    echo "Full response from HCP was:" >&2
    echo "$RESPONSE" >&2
    exit 1
  fi
  # Print as simple JSON with key=SECRET_NAME, value=secret_value
  echo "{\"${SECRET_NAME}\": \"${SECRET_VALUE}\"}"
else
  # Parse out all secrets into one JSON object
  ALL_SECRETS="$(echo "$RESPONSE" | jq -r '
    if .secrets then
      .secrets | map({(.name): .static_version.value}) | add
    else
      null
    end
  ')"

  if [ -z "$ALL_SECRETS" ] || [ "$ALL_SECRETS" = "null" ]; then
    echo "[ERROR] No secrets found for app '$HCP_APP_NAME' or invalid response." >&2
    echo "Full response from HCP was:" >&2
    echo "$RESPONSE" >&2
    exit 1
  fi

  # Print the combined secrets object
  echo "$ALL_SECRETS"
fi

