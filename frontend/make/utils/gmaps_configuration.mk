# -----------------------------------------------------------------------------
# Google Maps Configuration
# -----------------------------------------------------------------------------
SHELL := /bin/bash

.PHONY: _export_gmaps_vars

INCLUDED_GMAPS_CONFIGURATION := 1


# ------------------------------
# Targets
# ------------------------------

ifndef INCLUDED_APP_SECRETS_JSON
  include devops-toolkit/shared/make/utils/app_secrets_json.mk
endif

_export_gmaps_vars:
	@echo "[INFO] [Export Google Maps Vars] Exporting Google Maps environment variables..."
	$(eval export GMAPS_CLIENT_SDK_KEY := $(shell echo '$(APP_SECRETS_JSON)' | jq -r '.GMAPS_CLIENT_SDK_KEY'))
	@echo "[INFO] [Export Google Maps Vars] Google Maps environment variables exported."

_gmaps_configuration: _app_secrets_json _export_gmaps_vars
