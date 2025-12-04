# --------------------------------
# Backend Domain Utilities
# --------------------------------
# Shared utilities for resolving the public domain of a backend service.
#
# Prerequisites:
#   - BACKEND_GATEWAY_PATH must be set to the path of the backend Makefile
#
# Provides:
#   - _backend_domain_cmd: Command to get the public domain of the backend
#
# Usage in recipes:
#   domain="$$( $(_backend_domain_cmd) )"; rc=$$?; \
#   [ $$rc -eq 0 ] || exit $$rc; \
#   echo "Domain: $$domain"
#
# Note: Health check output goes to stderr (visible), domain to stdout (captured)

ifndef INCLUDED_BACKEND_DOMAIN_UTILS

ifndef BACKEND_GATEWAY_PATH
  $(error [ERROR] [Backend Domain Utils] BACKEND_GATEWAY_PATH must be set before including this file.)
endif

# Command to get the public domain of the backend
# Runs print-public-app-domain which executes health_check.sh (stderr) then echoes domain (stdout)
_backend_domain_cmd = $(MAKE) -C $(BACKEND_GATEWAY_PATH) \
                      --no-print-directory PRINT_INFO=0 print-public-app-domain

INCLUDED_BACKEND_DOMAIN_UTILS := 1

endif # ifndef INCLUDED_BACKEND_DOMAIN_UTILS
