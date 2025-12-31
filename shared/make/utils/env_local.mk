# --------------------------
# Env Local (BWS)
# --------------------------
SHELL := /bin/bash

.PHONY: env-local

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef INCLUDED_ENV_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/shared/make/utils/env_configuration.mk
endif

# --------------------------------
# Internal Variable Declaration
# --------------------------------

ENV_LOCAL_FILE ?= .env.local
ENV_LOCAL_BWS_PROJECT ?= $(APP_NAME)-$(ENV)

# --------------------------------
# Targets
# --------------------------------

## Generates .env.local from Bitwarden (ENV=dev only). Updates if secrets changed.
env-local:
	@if [ "$(ENV)" != "$(DEV_ENV)" ]; then \
		echo "[INFO] [Env-Local] ENV=$(ENV) (only runs when ENV=$(DEV_ENV)); skipping."; \
		exit 0; \
	fi
	@if [ -z "$$BWS_ACCESS_TOKEN" ]; then \
		echo "[ERROR] [Env-Local] BWS_ACCESS_TOKEN is required to fetch secrets." >&2; \
		exit 1; \
	fi
	@echo "[INFO] [Env-Local] Generating $(ENV_LOCAL_FILE) from BWS project $(ENV_LOCAL_BWS_PROJECT)..."
	@"$(DEVOPS_TOOLKIT_PATH)/shared/scripts/write_env_local_from_bws.sh" "$(ENV_LOCAL_BWS_PROJECT)" "$(ENV_LOCAL_FILE)"


INCLUDED_ENV_LOCAL_UTILS := 1
