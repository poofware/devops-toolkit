#!/usr/bin/env bash
set -euo pipefail

trap 'echo; echo "[INFO] Interrupted - exiting."; exit 130' INT

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "[ERROR] ${name} is required." >&2
    exit 1
  fi
}

require_env CLOUDFLARE_API_TOKEN
require_env CLOUDFLARE_ACCOUNT_ID
require_env CLOUDFLARE_ZONE_ID
require_env CLOUDFLARED_TUNNEL_NAME
require_env CLOUDFLARED_HOSTNAME
require_env APP_URL_FROM_COMPOSE_NETWORK

API_BASE="https://api.cloudflare.com/client/v4"

cf_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sf -X "$method" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$data" \
      "${API_BASE}${path}"
  else
    curl -sf -X "$method" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      "${API_BASE}${path}"
  fi
}

require_success() {
  local resp="$1"
  if ! echo "$resp" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "[ERROR] Cloudflare API error:" >&2
    echo "$resp" | jq -c '.errors // .messages // .result' >&2 || true
    exit 1
  fi
}

echo "[INFO] Ensuring Cloudflare tunnel exists..." >&2

# 1) Find existing tunnel by name (best-effort list)
tunnels_json="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel")"
require_success "$tunnels_json"
tunnel_id="$(echo "$tunnels_json" | jq -r --arg name "$CLOUDFLARED_TUNNEL_NAME" '.result[] | select(.name == $name) | .id' | head -1)"

tunnel_token=""

if [[ -z "$tunnel_id" ]]; then
  create_payload="$(jq -n --arg name "$CLOUDFLARED_TUNNEL_NAME" '{name:$name}')"
  create_json="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel" "$create_payload")"
  require_success "$create_json"
  tunnel_id="$(echo "$create_json" | jq -r '.result.id // empty')"
  tunnel_token="$(echo "$create_json" | jq -r '.result.token // empty')"
  echo "[INFO] Tunnel created: ${tunnel_id}" >&2
else
  token_json="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/token")"
  require_success "$token_json"
  tunnel_token="$(echo "$token_json" | jq -r 'if (.result|type)=="string" then .result elif (.result|type)=="object" then .result.token else empty end')"
  echo "[INFO] Tunnel exists: ${tunnel_id}" >&2
fi

if [[ -z "$tunnel_id" || -z "$tunnel_token" ]]; then
  echo "[ERROR] Failed to resolve tunnel id/token." >&2
  exit 1
fi

# 2) Configure ingress (hostname -> local service)
config_payload="$(jq -n \
  --arg hostname "$CLOUDFLARED_HOSTNAME" \
  --arg service "$APP_URL_FROM_COMPOSE_NETWORK" \
  '{config:{ingress:[{hostname:$hostname,service:$service},{service:"http_status:404"}]}}')"
config_resp="$(cf_api PUT "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/configurations" "$config_payload")"
require_success "$config_resp"

# 3) Ensure DNS record (hostname -> <tunnel_id>.cfargotunnel.com)
cname_target="${tunnel_id}.cfargotunnel.com"
dns_list="$(cf_api GET "/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=CNAME&name=${CLOUDFLARED_HOSTNAME}")"
require_success "$dns_list"
record_id="$(echo "$dns_list" | jq -r '.result[0].id // empty')"
dns_payload="$(jq -n --arg name "$CLOUDFLARED_HOSTNAME" --arg content "$cname_target" \
  '{type:"CNAME",name:$name,content:$content,proxied:true}')"

if [[ -z "$record_id" ]]; then
  create_dns_resp="$(cf_api POST "/zones/${CLOUDFLARE_ZONE_ID}/dns_records" "$dns_payload")"
  require_success "$create_dns_resp"
  echo "[INFO] DNS record created for ${CLOUDFLARED_HOSTNAME}" >&2
else
  update_dns_resp="$(cf_api PUT "/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" "$dns_payload")"
  require_success "$update_dns_resp"
  echo "[INFO] DNS record updated for ${CLOUDFLARED_HOSTNAME}" >&2
fi

echo "$tunnel_token"
