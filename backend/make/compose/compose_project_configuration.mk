# ----------------------------------------------------
# Compose Project Configuration
# ----------------------------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a project by verifying that the Makefile exists. 
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

INCLUDED_COMPOSE_PROJECT_CONFIGURATION := 1


# --------------------------------
# External Variable Validation
# --------------------------------

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

ifndef INCLUDED_ENV_CONFIGURATION
  include devops-toolkit/backend/make/utils/env_configuration.mk
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

ifneq ($(origin COMPOSE_PROJECT_NAME), file)
  $(error COMPOSE_PROJECT_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Example: COMPOSE_PROJECT_NAME="account-service")
endif

ifneq ($(origin COMPOSE_FILE), file)
  $(error COMPOSE_FILE is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Should be a colon-separated list of additional compose files to include in the docker compose command. \
	Define it empty if no additional compose files are needed. \
	Example: COMPOSE_FILE="devops-toolkit/backend/docker/additional.compose.yaml:./override.compose.yaml" or COMPOSE_FILE="")
endif

ifneq ($(origin DEPS), file)
  $(error DEPS is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if your app has no dependency apps. \
	Example: DEPS="/path/to/auth-service /path/to/account-service" or DEPS="")
endif

# ------------------------------
# Internal Variable Declaration
# ------------------------------ 

# Functions in make should always use '=', unless precomputing the value without dynamic args
print-dep = $(info   $(word 1, $(subst :, ,$1)) = $(word 2, $(subst :, ,$1)))

ifndef ALREADY_PRINTED_DEPS
  export ALREADY_PRINTED_DEPS := 1

  ifeq ($(WITH_DEPS),1)
    $(info --------------------------------------------------)
    $(info [INFO] WITH_DEPS is enabled. Effective dependency projects being used:)
    $(info --------------------------------------------------)
    ifneq ($(DEPS),"")
  	$(foreach dep, $(DEPS), $(call print-dep, $(dep)))
    endif
    $(info )
    $(info --------------------------------------------------)
    $(info [INFO] To override, make with VAR=value)
    $(info )
  endif
endif

ifndef INCLUDED_HCP_CONSTANTS
  include devops-toolkit/backend/make/utils/hcp_constants.mk
endif
ifndef INCLUDED_LAUNCHDARKLY_CONSTANTS
  include devops-toolkit/backend/make/utils/launchdarkly_constants.mk
endif

export COMPOSE_FILE
# For isolation of CI runs, and use of 3rd party services (e.g. Stripe)
export UNIQUE_RUN_NUMBER ?= 0
export UNIQUE_RUNNER_ID
export COMPOSE_NETWORK_NAME

COMPOSE_PROFILE_BASE_APP := base_app
COMPOSE_PROFILE_BASE_DB := base_db
COMPOSE_PROFILE_BASE_MIGRATE := base_migrate
COMPOSE_PROFILE_BASE_APP_INTEGRATION_TEST := base_app_integration_test

COMPOSE_PROFILE_APP := app
COMPOSE_PROFILE_DB := db
COMPOSE_PROFILE_MIGRATE := migrate
COMPOSE_PROFILE_APP_PRE := app_pre
COMPOSE_PROFILE_APP_POST_CHECK := app_post_check
COMPOSE_PROFILE_APP_INTEGRATION_TEST := app_integration_test
COMPOSE_PROFILE_APP_UNIT_TEST := app_unit_test

# Probably a better way to do this
COMPOSE_DOWN_PROFILE_FLAGS := --profile $(COMPOSE_PROFILE_APP)
COMPOSE_DOWN_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_DB)
COMPOSE_DOWN_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_MIGRATE)
COMPOSE_DOWN_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_APP_PRE)
COMPOSE_DOWN_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_APP_POST_CHECK)

COMPOSE_PROJECT_DIR := ./

# Variable for app run/up/down docker compose commands
COMPOSE_CMD := docker compose \
		       --project-directory $(COMPOSE_PROJECT_DIR) \
			   -p $(COMPOSE_PROJECT_NAME)

ifndef INCLUDE_COMPOSE_SERVICE_UTILS
  include devops-toolkit/backend/make/compose/compose_service_utils.mk
endif

COMPOSE_PROFILE_BASE_APP_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_BASE_APP))
COMPOSE_PROFILE_BASE_DB_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_BASE_DB))
COMPOSE_PROFILE_BASE_MIGRATE_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_BASE_MIGRATE))
COMPOSE_PROFILE_BASE_APP_INTEGRATION_TEST_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_BASE_APP_INTEGRATION_TEST))

COMPOSE_PROFILE_APP_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_APP))
COMPOSE_PROFILE_DB_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_DB))
COMPOSE_PROFILE_MIGRATE_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_MIGRATE))
COMPOSE_PROFILE_APP_PRE_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_APP_PRE))
COMPOSE_PROFILE_APP_POST_CHECK_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_APP_POST_CHECK))
COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_APP_INTEGRATION_TEST))
COMPOSE_PROFILE_APP_UNIT_TEST_SERVICES = $(call get_profile_services,$(COMPOSE_PROFILE_APP_UNIT_TEST))

COMPOSE_BUILD_BASE_SERVICES = $(COMPOSE_PROFILE_BASE_APP_SERVICES) \
							  $(COMPOSE_PROFILE_BASE_DB_SERVICES) \
							  $(COMPOSE_PROFILE_BASE_MIGRATE_SERVICES)

COMPOSE_BUILD_SERVICES = $(COMPOSE_PROFILE_APP_SERVICES) \
						 $(COMPOSE_PROFILE_DB_SERVICES) \
						 $(COMPOSE_PROFILE_MIGRATE_SERVICES) \
						 $(COMPOSE_PROFILE_APP_PRE_SERVICES) \
						 $(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)
