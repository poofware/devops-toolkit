# --------------------------------
# Next.js App Targets
# --------------------------------

SHELL := /bin/bash

.PHONY: help up-backend down-backend clean-backend logs \
	_export_current_backend_domain

# Check that the current working directory is the root of a Next.js app by verifying that package.json exists.
ifeq ($(wildcard package.json),)
  $(error Error: package.json not found. Please ensure you are in the root directory of your Next.js app.)
endif

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef INCLUDED_NEXTJS_APP_CONFIGURATION
  $(error [ERROR] [Next.js App Targets] The Next.js App Configuration must be included before any Next.js App Targets. \
	Include $$(DEVOPS_TOOLKIT_PATH)/frontend/make/utils/nextjs_app_configuration.mk in your root Makefile.)
endif


# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_HELP
  include $(DEVOPS_TOOLKIT_PATH)/shared/make/help.mk
endif

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
# Export the current backend domain based on the environment
# --------------------------------
_backend_domain_cmd = $(MAKE) -C $(BACKEND_GATEWAY_PATH) \
                      --no-print-directory PRINT_INFO=0 print-public-app-domain

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

help::
	@echo "--------------------------------------------------"
	@echo "[INFO] Next.js App Configuration:"
	@echo "--------------------------------------------------"
	@echo "ENV: $(ENV)"
	@echo "AUTO_LAUNCH_BACKEND: $(AUTO_LAUNCH_BACKEND)"
	@echo "VERBOSE: $(VERBOSE)"
	@echo "BACKEND_GATEWAY_PATH: $(BACKEND_GATEWAY_PATH)"
	@echo
	@echo "Backend Options:"
	@echo "  make up                        - Use default AUTO_LAUNCH_BACKEND for ENV"
	@echo "  make up AUTO_LAUNCH_BACKEND=1  - Force backend to auto-start"
	@echo "  make up AUTO_LAUNCH_BACKEND=0  - Skip backend (use web workers fallback)"
	@echo


INCLUDED_NEXTJS_APP_TARGETS := 1
