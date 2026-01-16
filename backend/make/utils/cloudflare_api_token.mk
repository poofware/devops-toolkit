# ---------------------------------------
# Cloudflare API credentials for local development
# (Fetched only from BWS - no local overrides)
# ---------------------------------------

SHELL := bash

.PHONY: _export_cloudflare_api_token

ifndef INCLUDED_ENV_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/shared/make/utils/env_configuration.mk
endif

# Default BWS project: app-env (dev-test maps to dev)
CLOUDFLARE_BWS_PROJECT ?= $(APP_NAME)-$(if $(filter $(ENV),$(DEV_TEST_ENV)),$(DEV_ENV),$(ENV))

_export_cloudflare_api_token:
ifndef CLOUDFLARE_API_TOKEN_UP
	$(eval export CLOUDFLARE_API_TOKEN_UP := 1)
	$(if $(filter environment command line,$(origin CLOUDFLARE_API_TOKEN)),$(error CLOUDFLARE_API_TOKEN must not be set directly. It is fetched from BWS only.),)
	$(if $(BWS_ACCESS_TOKEN),,$(error BWS_ACCESS_TOKEN is required to fetch Cloudflare credentials from BWS.))
	$(if $(and $(CLOUDFLARE_API_TOKEN),$(CLOUDFLARE_ACCOUNT_ID),$(CLOUDFLARE_ZONE_ID)),, \
		$(eval CLOUDFLARE_SECRETS_JSON := $(shell \
			BWS_PROJECT_NAME="$(CLOUDFLARE_BWS_PROJECT)" \
			$(DEVOPS_TOOLKIT_PATH)/shared/scripts/fetch_bws_secret.sh \
		)) \
		$(if $(CLOUDFLARE_SECRETS_JSON),,$(error Failed to fetch BWS secrets for Cloudflare.)) \
	)
	$(if $(CLOUDFLARE_API_TOKEN),,$(eval CLOUDFLARE_API_TOKEN := $(shell printf '%s' '$(CLOUDFLARE_SECRETS_JSON)' | jq -r '.CLOUDFLARE_API_TOKEN // empty')))
	$(if $(CLOUDFLARE_API_TOKEN),$(info [INFO] [Cloudflare] API token fetched from BWS.),)
	$(if $(CLOUDFLARE_ACCOUNT_ID),,$(eval CLOUDFLARE_ACCOUNT_ID := $(shell printf '%s' '$(CLOUDFLARE_SECRETS_JSON)' | jq -r '.CLOUDFLARE_ACCOUNT_ID // empty')))
	$(if $(CLOUDFLARE_ACCOUNT_ID),$(info [INFO] [Cloudflare] Account ID fetched from BWS.),)
	$(if $(CLOUDFLARE_ZONE_ID),,$(eval CLOUDFLARE_ZONE_ID := $(shell printf '%s' '$(CLOUDFLARE_SECRETS_JSON)' | jq -r '.CLOUDFLARE_ZONE_ID // empty')))
	$(if $(CLOUDFLARE_ZONE_ID),$(info [INFO] [Cloudflare] Zone ID fetched from BWS.),)
	$(if $(CLOUDFLARE_API_TOKEN),,$(error CLOUDFLARE_API_TOKEN is required (BWS secret missing).))
	$(if $(CLOUDFLARE_ACCOUNT_ID),,$(error CLOUDFLARE_ACCOUNT_ID is required (BWS secret missing).))
	$(if $(CLOUDFLARE_ZONE_ID),,$(error CLOUDFLARE_ZONE_ID is required (BWS secret missing).))
endif

INCLUDED_CLOUDFLARE_API_TOKEN := 1
