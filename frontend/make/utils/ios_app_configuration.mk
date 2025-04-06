# -----------------------------------------------------------------------------
# iOS App Configuration
# -----------------------------------------------------------------------------
SHELL := /bin/bash

.PHONY: _ios_app_configuration

INCLUDED_IOS_APP_CONFIGURATION := 1


# ------------------------------
# Targets
# ------------------------------

ifndef INCLUDED_GMAPS_CONFIGURATION
  include devops-toolkit/frontend/make/utils/gmaps_configuration.mk
endif

_ios_app_configuration: _gmaps_configuration
	@echo "[INFO] [Android App Configuration] All required Android environment variables have been exported."

