# --------------------------------
# Frontend Backend Utilities
# --------------------------------
# Shared utilities for frontend apps (Next.js, Flutter, etc.) that need
# to interact with a backend service.
#
# Prerequisites:
#   - BACKEND_GATEWAY_PATH must be set to the path of the backend Makefile
#   - bootstrap.mk must be included before this file
#
# Provides:
#   - up-backend, down-backend, clean-backend targets
#   - _export_current_backend_domain for shell export (eval in shell scripts)

SHELL := bash

ifndef INCLUDED_FRONTEND_BACKEND_UTILS

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef BACKEND_GATEWAY_PATH
  $(error [ERROR] [Frontend Backend Utils] BACKEND_GATEWAY_PATH must be set before including this file.)
endif

# Include shared backend domain utilities
ifndef INCLUDED_BACKEND_DOMAIN_UTILS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/utils/backend_domain_utils.mk
endif

# --------------------------------
# Shared Targets
# --------------------------------

.PHONY: logs up-backend down-backend clean-backend _export_current_backend_domain

## Create logs directory
logs:
	@mkdir -p logs

## Up the backend
up-backend:
	@echo "[INFO] [Up Backend] Starting backend for ENV=$(ENV)..."
	@$(MAKE) -C $(BACKEND_GATEWAY_PATH) up PRINT_INFO=0

## Down the backend
down-backend:
	@echo "[INFO] [Down Backend] Stopping backend for ENV=$(ENV)..."
	@$(MAKE) -C $(BACKEND_GATEWAY_PATH) down PRINT_INFO=0

## Clean the backend
clean-backend:
	@echo "[INFO] [Clean Backend] Cleaning backend for ENV=$(ENV)..."
	@$(MAKE) -C $(BACKEND_GATEWAY_PATH) clean PRINT_INFO=0

# --------------------------------
# Backend Domain Resolution
# --------------------------------

# Export backend domain as shell variable (for eval in shell scripts)
# Usage: eval "$$( $(MAKE) _export_current_backend_domain --no-print-directory )"
_export_current_backend_domain:
	@echo "[INFO] [Export Backend Domain] Exporting backend domain for ENV=$(ENV)..." >&2
ifneq (,$(filter $(ENV),$(DEV_TEST_ENV)))
	@if [ -z "$$CURRENT_BACKEND_DOMAIN" ]; then \
		domain="$$( $(_backend_domain_cmd) )"; rc=$$?; \
		[ $$rc -eq 0 ] || exit $$rc; \
		echo "export CURRENT_BACKEND_DOMAIN=\"$$domain\""; \
	fi
else
	@domain="$$( $(_backend_domain_cmd) )"; rc=$$?; \
	[ $$rc -eq 0 ] || exit $$rc; \
	echo "export CURRENT_BACKEND_DOMAIN=\"$$domain\""
endif

INCLUDED_FRONTEND_BACKEND_UTILS := 1

endif # ifndef INCLUDED_FRONTEND_BACKEND_UTILS
