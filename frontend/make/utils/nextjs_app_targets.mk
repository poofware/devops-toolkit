# --------------------------------
# Next.js App Targets
# --------------------------------

SHELL := /bin/bash

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
ifdef NEXTJS_BACKEND_ENV_VAR
  FRONTEND_BACKEND_ENV_VAR := $(NEXTJS_BACKEND_ENV_VAR)
endif

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
