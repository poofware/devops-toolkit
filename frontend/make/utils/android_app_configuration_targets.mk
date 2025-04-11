# -----------------------------------------------------------------------------
# Android App Configuration Targets
# -----------------------------------------------------------------------------
SHELL := /bin/bash

.PHONY: _android_app_configuration


# ------------------------------
# Targets
# ------------------------------

ifndef INCLUDED_ANDROID_KEYSTORE_CONFIGURATION_TARGETS
  include devops-toolkit/frontend/make/utils/android_keystore_configuration_targets.mk
endif

ifndef INCLUDED_GMAPS_CONFIGURATION_TARGETS
  include devops-toolkit/frontend/make/utils/gmaps_configuration_targets.mk
endif

_android_app_configuration: _android_keystore_configuration _gmaps_configuration
	@echo "[INFO] [Android App Configuration] All required Android environment variables have been exported."


INCLUDED_ANDROID_APP_CONFIGURATION_TARGETS := 1
