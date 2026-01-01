# ----------------------------------
# Shuttle Constants
# ----------------------------------

SHELL := bash

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif


# ----------------------
# Shuttle Configuration
# ----------------------

# Shuttle project name - defaults to APP_NAME but can be overridden
SHUTTLE_PROJECT_NAME ?= $(APP_NAME)

# Shuttle URL pattern
SHUTTLE_URL = https://$(SHUTTLE_PROJECT_NAME).shuttle.app

# Shuttle API key environment variable name
SHUTTLE_API_KEY_ENV_VAR := SHUTTLE_API_KEY


INCLUDED_SHUTTLE_CONSTANTS := 1
