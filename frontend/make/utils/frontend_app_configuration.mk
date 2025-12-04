# --------------------------------
# Frontend App Configuration (Shared)
# --------------------------------
# Common configuration for frontend apps (Next.js, Flutter, etc.)
#
# Prerequisites:
#   - bootstrap.mk must be included before this file
#   - APP_NAME must be set in root Makefile
#   - BACKEND_GATEWAY_PATH must be set in root Makefile
#
# Provides:
#   - Variable validation (APP_NAME, BACKEND_GATEWAY_PATH)
#   - Common variables (LOG_LEVEL, VERBOSE, VERBOSE_FLAG)
#   - run_command_with_backend macro

SHELL := /bin/bash

ifndef INCLUDED_FRONTEND_APP_CONFIGURATION

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

# ------------------------------
# External Variable Validation
# ------------------------------

ifneq ($(origin APP_NAME), file)
  $(error APP_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile.)
endif

ifneq ($(origin BACKEND_GATEWAY_PATH), file)
  $(error BACKEND_GATEWAY_PATH is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile.)
endif

# ------------------------------
# Internal Variable Declaration
# ------------------------------

ifndef INCLUDED_ENV_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/shared/make/utils/env_configuration.mk
endif

LOG_LEVEL ?= info

export BWS_PROJECT_NAME := $(APP_NAME)

VERBOSE ?= 0
VERBOSE_FLAG := $(if $(filter 1,$(VERBOSE)),--verbose,)

# -------------------------------------------------
# Macro: run_command_with_backend
#
# Runs a command with the backend up if AUTO_LAUNCH_BACKEND=1.
# Otherwise, runs the command directly.
# Note: This is provided so that frontend developers have as little backend friction
#       as possible. Full stack developers can turn this feature off by setting
#       AUTO_LAUNCH_BACKEND=0 with their make command.
# $(1) is the command to run.
# -------------------------------------------------
define run_command_with_backend
	if [ $(AUTO_LAUNCH_BACKEND) -eq 1 ]; then \
		echo "[INFO] [Auto Launch Backend] Auto launching backend..."; \
		echo "[INFO] [Auto Launch Backend] Calling 'up-backend' target..."; \
		$(MAKE) up-backend --no-print-directory; \
		$(1) || exit 1; \
	else \
		$(1); \
	fi
endef


INCLUDED_FRONTEND_APP_CONFIGURATION := 1

endif # ifndef INCLUDED_FRONTEND_APP_CONFIGURATION
