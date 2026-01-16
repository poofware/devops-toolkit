# --------------------------------
# Next.js App Targets
# --------------------------------

SHELL := bash

.PHONY: help

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
# Include shared backend utilities
# --------------------------------
# Map Next.js specific variable to the generic one used by the shared utils
# (Removed mapping per request - utilizing NEXTJS_BACKEND_ENV_VAR directly in compose_app_targets.mk)
# ifdef NEXTJS_BACKEND_ENV_VAR
#   FRONTEND_BACKEND_ENV_VAR := $(NEXTJS_BACKEND_ENV_VAR)
# endif

ifndef INCLUDED_FRONTEND_BACKEND_UTILS
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/utils/frontend_backend_utils.mk
endif

# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_HELP
  include $(DEVOPS_TOOLKIT_PATH)/shared/make/help.mk
endif

# --------------------------------
# Help
# --------------------------------

help::
	@echo "--------------------------------------------------"
	@echo "[INFO] Frontend Runtime Configuration:"
	@echo "--------------------------------------------------"
	@echo "ENV: $(ENV)"
	@echo "WITH_DEPS: $(WITH_DEPS)"
	@echo "FRONTEND_RELEASE_MODE: $(FRONTEND_RELEASE_MODE)"
	@echo "FRONTEND_NODE_ENV: $(FRONTEND_NODE_ENV)"
	@echo "NEXT_PUBLIC_ENV: $(NEXT_PUBLIC_ENV)"
	@echo "NEXT_PUBLIC_DEVTOOLS_ENABLED: $(NEXT_PUBLIC_DEVTOOLS_ENABLED)"
	@echo "NEXT_PUBLIC_GENERATOR_URL: $(NEXT_PUBLIC_GENERATOR_URL)"
	@echo "NEXT_PUBLIC_DEV_GENERATOR_URL: $(NEXT_PUBLIC_DEV_GENERATOR_URL)"
	@echo "ENABLE_NGROK_FOR_DEV: $(ENABLE_NGROK_FOR_DEV)"
	@echo "ENABLE_CLOUDFLARED_FOR_DEV: $(ENABLE_CLOUDFLARED_FOR_DEV)"
	@echo "CLOUDFLARED_HOSTNAME: $(CLOUDFLARED_HOSTNAME)"
	@echo "BACKEND_GATEWAY_PATH: $(BACKEND_GATEWAY_PATH)"
	@echo
	@echo "Backend Options:"
	@echo "  make up                        - Uses default backend policy for ENV"
	@echo "  make up WITH_DEPS=1           - Force backend to auto-start"
	@echo "  make up WITH_DEPS=0           - Skip backend (use WASM workers)"
	@echo


INCLUDED_NEXTJS_APP_TARGETS := 1
