# ------------------------------
# App Configuration
# ------------------------------

SHELL := /bin/bash

INCLUDED_APP_CONFIGURATION := 1

ifndef INCLUDED_COMPOSE_PROJECT_CONFIGURATION
  $(error [ERROR] [App Compose Configuration] The Compose Project Configuration must be included before any compose file configuration. \
	Include devops-toolkit/backend/make/compose/compose_project_configuration.mk in your root Makefile.)
endif

# --------------------------------
# External Variable Validation
# --------------------------------

# Root Makefile variables, possibly overridden by the environment #

ifndef APP_PORT
  $(error APP_PORT is not set. Please define it in your local Makefile or runtime/ci environment. \
	Example: APP_PORT=8080)
endif

# Root Makefile variables #

ifneq ($(origin APP_NAME), file)
  $(error APP_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Example: APP_NAME="account-service")
endif

# Optional override configuration env variables #

ifdef APP_URL_FROM_COMPOSE_NETWORK
  ifeq ($(origin APP_URL_FROM_COMPOSE_NETWORK), file)
    $(error APP_URL_FROM_COMPOSE_NETWORK override should be set as a runtime/ci environment variable, do not hardcode it in the root Makefile. \
	  Example: APP_URL_FROM_COMPOSE_NETWORK="http://meta-service:8080" make integration-test)
  endif
endif

# ------------------------------
# Internal Variable Declaration
# ------------------------------

# For specific docker compose fields in our configuration
export APP_NAME
export APP_PORT

# Allow for APP_URL_FROM_COMPOSE_NETWORK override
ifneq (,$(filter $(ENV),$(DEV_TEST_ENV) $(DEV_ENV)))
  ifndef APP_URL_FROM_COMPOSE_NETWORK
    export APP_URL_FROM_COMPOSE_NETWORK := http://$(APP_NAME):$(APP_PORT)
  endif
  export APP_HOST_PORT ?= $(shell devops-toolkit/backend/scripts/find_available_port.sh 8080)
  export APP_URL_FROM_ANYWHERE ?= http://$(shell devops-toolkit/backend/scripts/get_lan_ip.sh):$(APP_HOST_PORT)
else
  # Staging and prod not supported at this time.
endif

