# -----------------------------------------------------------------------------
# Android App Configuration
# -----------------------------------------------------------------------------
SHELL := /bin/bash

.PHONY: _android_app_configuration

INCLUDED_ANDROID_APP_CONFIGURATION := 1


# ------------------------------
# Targets
# ------------------------------

ifndef INCLUDED_ANDROID_KEYSTORE_CONFIGURATION
  include devops-toolkit/frontend/make/utils/android_keystore_configuration.mk
endif

ifndef INCLUDED_GMAPS_CONFIGURATION
  include devops-toolkit/frontend/make/utils/gmaps_configuration.mk
endif

_android_app_configuration: _android_keystore_configuration _gmaps_configuration
	@echo "[INFO] [Android App Configuration] All required Android environment variables have been exported."

