# ------------------------------
# Go App Makefile
#  
# This Makefile is intended to be included in the main Makefile
# in the root of a Go service.
# ------------------------------

SHELL := /bin/bash

.PHONY: ci update help

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP := 1


################################
# External Variable Validation #
################################

# Runtime/Ci environment variables #

# Will need the client id and client secret to fetch the HCP API token
# if HCP_ENCRYPTED_API_TOKEN is not already set
ifndef HCP_ENCRYPTED_API_TOKEN
  ifneq ($(origin HCP_CLIENT_ID), environment)
    $(error HCP_CLIENT_ID is either not set or set in the root Makefile. Please define it in your runtime/ci environment only. \
	  Example: export HCP_CLIENT_ID="my_client_id")
  endif

  ifneq ($(origin HCP_CLIENT_SECRET), environment)
    $(error HCP_CLIENT_SECRET is either not set or set in the root Makefile. Please define it in your runtime/ci environment only. \
      Example: export HCP_CLIENT_SECRET="my_client_secret")
  endif
endif

ifneq ($(origin HCP_TOKEN_ENC_KEY), environment)
  $(error HCP_TOKEN_ENC_KEY is either not set or set in the root Makefile. Please define it in your runtime/ci environment only. \
    Example: export HCP_TOKEN_ENC_KEY="my_encryption_key")
endif

ifneq ($(origin UNIQUE_RUNNER_ID), environment)
  $(error UNIQUE_RUNNER_ID is either not set or set in the root Makefile. Please define it in your runtime/ci environment only. \
	Example: export UNIQUE_RUNNER_ID="john_snow")
endif

# Root Makefile variables, possibly overridden by the environment #

ifndef INCLUDED_ENV_VALIDATION
  include devops-toolkit/backend/make/utils/env_validation.mk
endif

ifndef APP_PORT
  $(error APP_PORT is not set. Please define it in your local Makefile or runtime/ci environment. \
	Example: APP_PORT=8080)
endif

ifndef COMPOSE_NETWORK_NAME
  $(error COMPOSE_NETWORK_NAME is not set. Please define it in your local Makefile or runtime/ci environment. \
	Example: COMPOSE_NETWORK_NAME="shared_service_network")
endif

ifndef WITH_DEPS
  $(error WITH_DEPS is not set. Please define it in your local Makefile or runtime/ci environment. \
	Example: WITH_DEPS=1)
endif

# Root Makefile variables #

ifneq ($(origin APP_NAME), file)
  $(error APP_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Example: APP_NAME="account-service")
endif

ifneq ($(origin PACKAGES), file)
  $(error PACKAGES is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if your app has no dependency packages. \
    Example: PACKAGES="go-middleware go-repositories go-utils go-models" or PACKAGES="")
endif

ifneq ($(origin DEPS), file)
  $(error DEPS is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if your app has no dependency apps. \
	Example: DEPS="/path/to/auth-service /path/to/account-service" or DEPS="")
endif

ifneq ($(origin ADDITIONAL_COMPOSE_FILES), file)
  $(error ADDITIONAL_COMPOSE_FILES is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Should be a colon-separated list of additional compose files to include in the docker compose command. \
	Define it empty if no additional compose files are needed. \
	Example: ADDITIONAL_COMPOSE_FILES="devops-toolkit/backend/docker/additional.compose.yaml:./override.compose.yaml" or ADDITIONAL_COMPOSE_FILES="")
endif

# Optional override configuration env variables #

ifdef APP_URL
  ifneq ($(origin APP_URL), environment)
    $(error APP_URL override should be set as a runtime/ci environment variable, do not hardcode it in the root Makefile. \
	  Example: APP_URL="http://meta-service:8080" make integration-test)
  endif
endif


# ------------------------------
# Internal Variable Declaration
# ------------------------------

# Functions in make should always use '=', unless precomputing the value without dynamic args
print-dep = $(info   $(word 1, $(subst :, ,$1)) = $(word 2, $(subst :, ,$1)))

ifndef ALREADY_PRINTED_DEPS
  ifeq ($(WITH_DEPS),1)
    $(info --------------------------------------------------)
    $(info [INFO] WITH_DEPS is enabled. Effective dependency services being used:)
    $(info --------------------------------------------------)
    ifneq ($(DEPS),"")
  	$(foreach dep, $(DEPS), $(call print-dep, $(dep)))
    endif
    $(info )
    $(info [INFO] To override, make with VAR=value)
    $(info --------------------------------------------------)
  endif

  export ALREADY_PRINTED_DEPS := 1
endif

# For updating go packages
export PACKAGES

# For specific docker compose fields in our configuration
export APP_NAME
export APP_PORT
export COMPOSE_NETWORK_NAME
export ENV
# For isolation of CI runs, and use of 3rd party services (e.g. Stripe)
export UNIQUE_RUN_NUMBER ?= 0
export UNIQUE_RUNNER_ID

# Allow for APP_URL override
ifndef APP_URL
  ifneq (,$(filter $(ENV),$(DEV_TEST_ENV) $(DEV_ENV)))
  	export APP_URL := http://$(APP_NAME):$(APP_PORT)
  else
    # Staging and prod not supported at this time.
  endif
endif

COMPOSE_PROFILE_APP := app
COMPOSE_PROFILE_DB := db
COMPOSE_PROFILE_MIGRATE := migrate
COMPOSE_PROFILE_APP_PRE := app_pre
COMPOSE_PROFILE_APP_POST_CHECK := app_post_check
COMPOSE_PROFILE_APP_INTEGRATION_TEST := app_integration_test
COMPOSE_PROFILE_APP_UNIT_TEST := app_unit_test

COMPOSE_PROFILE_FLAGS_UP_DOWN_BUILD := --profile $(COMPOSE_PROFILE_APP)
COMPOSE_PROFILE_FLAGS_UP_DOWN_BUILD += --profile $(COMPOSE_PROFILE_DB)
COMPOSE_PROFILE_FLAGS_UP_DOWN_BUILD += --profile $(COMPOSE_PROFILE_MIGRATE)
COMPOSE_PROFILE_FLAGS_UP_DOWN_BUILD += --profile $(COMPOSE_PROFILE_APP_PRE)
COMPOSE_PROFILE_FLAGS_UP_DOWN_BUILD += --profile $(COMPOSE_PROFILE_APP_POST_CHECK)

# For docker compose
# List in order of dependency, separate by ':'
export COMPOSE_FILE := devops-toolkit/backend/docker/go-app.compose.yaml
ifneq ($(ADDITIONAL_COMPOSE_FILES), "")
  export COMPOSE_FILE := $(COMPOSE_FILE):$(ADDITIONAL_COMPOSE_FILES)
endif

# For docker compose command options
COMPOSE_PROJECT_DIR := ./
COMPOSE_PROJECT_NAME := $(APP_NAME)

# Variable for app run/up/down docker compose commands
COMPOSE_CMD := docker compose \
		       --project-directory $(COMPOSE_PROJECT_DIR) \
			   -p $(COMPOSE_PROJECT_NAME)

ifndef INCLUDE_COMPOSE_SERVICE_UTILS
  include devops-toolkit/backend/make/utils/compose_service_utils.mk
endif
ifndef INCLUDED_HCP_CONSTANTS
  include devops-toolkit/backend/make/utils/hcp_constants.mk
endif
ifndef INCLUDED_LAUNCHDARKLY_CONSTANTS
  include devops-toolkit/backend/make/utils/launchdarkly_constants.mk
endif

ifndef ALREADY_GOT_PROFILE_SERVICES
  export COMPOSE_PROFILE_APP_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_APP))
  export COMPOSE_PROFILE_DB_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_DB))
  export COMPOSE_PROFILE_MIGRATE_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_MIGRATE))
  export COMPOSE_PROFILE_APP_PRE_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_APP_PRE))
  export COMPOSE_PROFILE_APP_POST_CHECK_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_APP_POST_CHECK))
  export COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_APP_INTEGRATION_TEST))
  export COMPOSE_PROFILE_APP_UNIT_TEST_SERVICES := $(call get_profile_services,$(COMPOSE_PROFILE_APP_UNIT_TEST))
  export ALREADY_GOT_PROFILE_SERVICES := 1
endif


# ------------------------------
# Go App Targets
# ------------------------------

ifndef INCLUDED_GO_APP_DEPS
  include devops-toolkit/backend/make/go-app/go_app_deps.mk
endif
ifndef INCLUDED_GO_APP_DOWN
  include devops-toolkit/backend/make/go-app/go_app_down.mk
endif
ifndef INCLUDED_GO_APP_BUILD
  include devops-toolkit/backend/make/go-app/go_app_build.mk
endif
ifndef INCLUDED_GO_APP_UP
  include devops-toolkit/backend/make/go-app/go_app_up.mk
endif
ifndef INCLUDED_GO_APP_TEST
  include devops-toolkit/backend/make/go-app/go_app_test.mk
endif
ifndef INCLUDED_GO_APP_CLEAN
  include devops-toolkit/backend/make/go-app/go_app_clean.mk
endif
ifndef INCLUDED_GO_APP_CI
  include devops-toolkit/backend/make/go-app/go_app_ci.mk
endif
ifndef INCLUDED_GO_APP_UPDATE
  include devops-toolkit/backend/make/go-app/go_app_update.mk
endif
ifndef INCLUDED_HELP
  include devops-toolkit/shared/make/help.mk
endif


## Lists available targets
help: _help
	@echo
	@echo "--------------------------------------------------"
	@echo "[INFO] Configuration variables:"
	@echo "--------------------------------------------------"
	@echo "APP_NAME: $(APP_NAME)"
	@echo "APP_PORT: $(APP_PORT)"
	@echo "COMPOSE_NETWORK_NAME: $(COMPOSE_NETWORK_NAME)"
	@echo "ENV: $(ENV)"
	@echo "UNIQUE_RUN_NUMBER: $(UNIQUE_RUN_NUMBER)"
	@echo "UNIQUE_RUNNER_ID: $(UNIQUE_RUNNER_ID)"
	@echo "WITH_DEPS: $(WITH_DEPS)"
	@echo "PACKAGES: $(PACKAGES)"
	@echo "DEPS: $(DEPS)"
	@echo "ADDITIONAL_COMPOSE_FILES: $(ADDITIONAL_COMPOSE_FILES)"
	@echo "APP_URL: $(APP_URL)"
	@echo "HCP_CLIENT_ID": xxxxxxxx
	@echo "HCP_CLIENT_SECRET": xxxxxxxx
	@echo "HCP_TOKEN_ENC_KEY": xxxxxxxx
	@echo "--------------------------------------------------"
	@echo
	@echo "--------------------------------------------------"
	@echo "[INFO] Effective compose services for each profile:"
	@echo "--------------------------------------------------"
	@echo "$(COMPOSE_PROFILE_APP)                  :$(COMPOSE_PROFILE_APP_SERVICES)"
	@echo "$(COMPOSE_PROFILE_DB)                   :$(COMPOSE_PROFILE_DB_SERVICES)"
	@echo "$(COMPOSE_PROFILE_MIGRATE)              :$(COMPOSE_PROFILE_MIGRATE_SERVICES)"
	@echo "$(COMPOSE_PROFILE_APP_PRE)              :$(COMPOSE_PROFILE_APP_PRE_SERVICES)"
	@echo "$(COMPOSE_PROFILE_APP_POST_CHECK)       :$(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)"
	@echo "$(COMPOSE_PROFILE_APP_INTEGRATION_TEST) :$(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)"
	@echo "$(COMPOSE_PROFILE_APP_UNIT_TEST)        :$(COMPOSE_PROFILE_APP_UNIT_TEST_SERVICES)"
	@echo "--------------------------------------------------"
	@echo "[INFO] For information on available profiles, reference devops-toolkit/README.md"

