# --------------------------------
# Flutter App Configuration
# --------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a Flutter app
ifeq ($(wildcard pubspec.yaml),)
  $(error Error: pubspec.yaml not found. Please ensure you are in the root directory of your Flutter app.)
endif

# Include shared frontend configuration
ifndef INCLUDED_FRONTEND_APP_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/utils/frontend_app_configuration.mk
endif


INCLUDED_FLUTTER_APP_CONFIGURATION := 1
