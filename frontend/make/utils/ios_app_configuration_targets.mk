# -----------------------------------------------------------------------------
# iOS App Configuration Targets
# -----------------------------------------------------------------------------
SHELL := /bin/bash

.PHONY: _ios_app_configuration


# ------------------------------
# Targets
# ------------------------------

ifndef INCLUDED_GMAPS_CONFIGURATION_TARGETS
  include devops-toolkit/frontend/make/utils/gmaps_configuration_targets.mk
endif

_ios_app_configuration: _gmaps_configuration
	@echo "[INFO] [Android App Configuration] All required Android environment variables have been exported."


INCLUDED_IOS_APP_CONFIGURATION_TARGETS := 1
