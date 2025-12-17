#!/usr/bin/env bash
#
# Script to find an available TCP port, with awareness of own container.
# Usage:
#   ./find_available_port.sh [START_PORT] [CONTAINER_NAME]
# If CONTAINER_NAME is provided and owns a port, that port is considered available
# (the container will be restarted and reclaim it).
# Prints the port number to stdout and exits with 0.

set -euo pipefail

START_PORT="${1:-8080}"
CONTAINER_NAME="${2:-}"

PORT="$START_PORT"

# Check if a port is held by our own container
is_own_container_port() {
  local check_port="$1"
  if [[ -z "$CONTAINER_NAME" ]]; then
    return 1
  fi
  # Get container holding this port via docker
  local holder
  holder=$(docker ps --format '{{.Names}}' --filter "publish=$check_port" 2>/dev/null | head -1)
  [[ "$holder" == "$CONTAINER_NAME" ]]
}

while true; do
  # Check if we can open a TCP connection to localhost:$PORT
  if (echo >/dev/tcp/127.0.0.1/"${PORT}") &>/dev/null; then
    # Port is in use - check if it's our own container
    if is_own_container_port "$PORT"; then
      # It's our container, we can reclaim this port
      echo "$PORT"
      exit 0
    fi
    # Someone else has it, increment and keep looking
    PORT=$((PORT + 1))
  else
    # Port is free
    echo "$PORT"
    exit 0
  fi
done
