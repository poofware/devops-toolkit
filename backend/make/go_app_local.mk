# ------------------------------
# Go App Makefile
#  
# This Makefile is intended to be included in the main Makefile
# in the root of a Go service.
# ------------------------------

SHELL := /bin/bash

.PHONY: up integration-test unit-test down ci clean

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP := 1


####################################
# Runtime/Ci environment variables #
####################################
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

###################################################################
# Root Makefile variables, possibly overridden by the environment #
###################################################################
include devops-toolkit/backend/make/utils/env_validation.mk

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

###########################
# Root Makefile variables #
###########################
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

#################################################
# Optional override configuration env variables #
#################################################

ifdef APP_URL
  ifneq ($(origin APP_URL), environment)
    $(error APP_URL override should be set as a runtime/ci environment variable, do not hardcode it in the root Makefile. \
	  Example: APP_URL="http://meta-service:8080" make integration-test)
  endif
endif


# Functions in make should always use '=', unless precomputing the value without dynamic args
print-dep = $(info   $(word 1, $(subst :, ,$1)) = $(word 2, $(subst :, ,$1)))

ifeq ($(WITH_DEPS),1)
  $(info --------------------------------------------------)
  $(info [INFO] WITH_DEPS is enabled. Effective dependency services being used:)
  ifneq ($(DEPS),"")
    $(foreach dep, $(DEPS), $(call print-dep, $(dep)))
  endif
  $(info )
  $(info [INFO] To override, make with VAR=value)
  $(info --------------------------------------------------)
endif

# For updating go packages
export PACKAGES

# For specific docker compose fields in our configuration
export APP_NAME
export APP_PORT
export COMPOSE_NETWORK_NAME
export ENV
# For isolation of CI runs, and use of 3rd party services (e.g. Stripe)
export UNIQUE_RUN_NUMBER ?= 9005
export UNIQUE_RUNNER_ID

# Allow for APP_URL override
ifndef APP_URL
  ifneq (,$(filter $(ENV),$(DEV_TEST_ENV) $(DEV_ENV)))
  	export APP_URL := http://$(APP_NAME):$(APP_PORT)
  else
    # Staging and prod not supported at this time.
  endif
endif

export COMPOSE_PROFILE_APP := app
export COMPOSE_PROFILE_DB := db
export COMPOSE_PROFILE_MIGRATE := migrate
export COMPOSE_PROFILE_APP_PRE_START := app_pre_start
export COMPOSE_PROFILE_APP_POST_START := app_post_start
# Only export this for name consistency compose, not used in the makefile
export COMPOSE_PROFILE_APP_TEST := app_test

# Needed by build target
COMPOSE_PROFILE_FLAGS := --profile $(COMPOSE_PROFILE_APP)
COMPOSE_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_DB)
COMPOSE_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_MIGRATE)
COMPOSE_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_APP_PRE_START)
COMPOSE_PROFILE_FLAGS += --profile $(COMPOSE_PROFILE_APP_POST_START)

# For docker compose
# List in order of dependency, separate by ':'
export COMPOSE_FILE := devops-toolkit/backend/docker/go-app.compose.yaml
ifneq ($(ADDITIONAL_COMPOSE_FILES), "")
  export COMPOSE_FILE := $(ADDITIONAL_COMPOSE_FILES):$(COMPOSE_FILE)
endif

# For docker compose command options
COMPOSE_PROJECT_DIR := ./
COMPOSE_PROJECT_NAME := $(APP_NAME)

# Variable for app run/up/down docker compose commands
COMPOSE_CMD := docker compose \
		       --project-directory $(COMPOSE_PROJECT_DIR) \
			   -p $(COMPOSE_PROJECT_NAME)


# Include path relative to the root of the project
include devops-toolkit/backend/make/utils/hcp_constants.mk
include devops-toolkit/backend/make/utils/launchdarkly_constants.mk
include devops-toolkit/backend/make/utils/go_app_deps.mk
include devops-toolkit/backend/make/utils/go_app_build.mk
include devops-toolkit/shared/make/help.mk


## Starts services for all compose profiles in order (PRE_START_PROFILES_ONLY=1 or POST_START_PROFILES_ONLY=1 to exclude app - WITH_DEPS=1 to 'up' dependency services as well)
up: _deps-up
	@echo "[INFO] [Up] Running down target to ensure clean state..."
	@$(MAKE) down WITH_DEPS=0

	@echo "[INFO] [Up] Running build target..."
	@$(MAKE) build WITH_DEPS=0

	@echo "[INFO] [Up] Starting any db services found matching the '$(COMPOSE_PROFILE_DB)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d 2>/dev/null || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d' failed (most likely no services found matching the '$(COMPOSE_PROFILE_DB)' profile OR the same db is already running) Ignoring..."
	@echo "[INFO] [Up] Done. Any db services found are up and running."

	@echo "[INFO] [Up] Starting any migration services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_MIGRATE) up 2>/dev/null || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_MIGRATE) up -d' failed (most likely no services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile) Ignoring..."
	@echo "[INFO] [Up] Done. Any migration services found were run."

	@echo "[INFO] [Up] Starting any pre-start services found matching the '$(COMPOSE_PROFILE_APP_PRE_START)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_PRE_START) up -d > /dev/null 2>&1 || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_PRE_START) up -d' failed (most likely no services found matching the '$(COMPOSE_PROFILE_APP_PRE_START)' profile) Ignoring..."
	@echo "[INFO] [Up] Done. Any pre-start services found are up and running."

	@if [ "$(PRE_START_PROFILES_ONLY)" = "1" ] || [ "$(POST_START_PROFILES_ONLY)" = "1" ]; then \
	  echo "[INFO] [Up] Skipping app startup as PRE_START_PROFILES_ONLY or POST_START_PROFILES_ONLY is set to 1..."; \
	else \
	  echo "[INFO] [Up] Spinning up app..."; \
	  echo "[INFO] [Up] Finding free host port for app to bind to..."; \
	  export APP_HOST_PORT=$$(devops-toolkit/backend/scripts/find_available_port.sh 8080); \
	  echo "[INFO] [Up] Found free host port: $$APP_HOST_PORT"; \
	  $(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP) up -d; \
	  echo "[INFO] [Up] Done. $$APP_NAME is running on http://localhost:$$APP_HOST_PORT"; \
	fi

	@echo "[INFO] [Up] Starting any post-start services found matching the '$(COMPOSE_PROFILE_APP_POST_START)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_POST_START) up -d > /dev/null 2>&1 || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_POST_START) up -d' failed (most likely no services found matching the '$(COMPOSE_PROFILE_APP_POST_START)' profile) Ignoring..."
	@echo "[INFO] [Up] Done. Any post-start services found are up and running."

# TODO: implement unit tests!!!
## 2) Run unit tests in a one-off container
# unit-test: build 
#	@echo "[INFO] [Unit Test] Running build target for unit-test service exclusively..."
#	@$(MAKE) build BUILD_SERVICES="unit-test"
#	@echo "[INFO] [Unit Test] 
#	$(COMPOSE_CMD) run --rm unit-test
#	@echo "[INFO] [Unit Test] Completed successfully!"
# TODO: implement unit tests!!!

## Runs integration tests in a one-off container
integration-test:
	@echo "[INFO] [Integration Test] Running build target for integration-test service exclusively..."
	@$(MAKE) build BUILD_SERVICES="integration-test" WITH_DEPS=0
	@echo "[INFO] [Integration Test] Starting...";
	@if ! $(COMPOSE_CMD) run --rm integration-test; then \
	  echo ""; \
	  echo "[ERROR] [Integration Test] FAILED. Collecting logs..."; \
	  $(COMPOSE_CMD) logs db app; \
	  exit 1; \
	fi
	@echo "[INFO] [Integration Test] Completed successfully!"

## Shuts down all containers (WITH_DEPS=1 to 'down' dependency services as well)
down: _deps-down
	@echo "[INFO] [Down] Removing containers & volumes, keeping images..."
	$(COMPOSE_CMD) $(COMPOSE_PROFILE_FLAGS) down -v --remove-orphans

## Cleans everything (containers, images, volumes) (WITH_DEPS=1 to 'clean' dependency services as well)
clean: _deps-clean
	@echo "[INFO] [Clean] Full nuke of containers, images, volumes, networks..."
	$(COMPOSE_CMD) $(COMPOSE_PROFILE_FLAGS) down --rmi local -v --remove-orphans
	@echo "[INFO] [Clean] Done."

## CI pipeline: Starts services, runs both integration and unit tests, and then shuts down all containers
ci:
	@echo "[INFO] [CI] Starting pipeline..."
	$(MAKE) up
	$(MAKE) integration-test
	@# $(MAKE) unit-test  # TODO: implement unit tests
	$(MAKE) down
	@echo "[INFO] [CI] Pipeline complete."

## Updates Go packages versions to the latest on specified branch (requires BRANCH to be set, e.g. BRANCH=main, applies to all packages)
update:
	@echo "[INFO] [Update] Updating Go packages..."
	@if [ -z "$(BRANCH)" ]; then \
		echo "[ERROR] [Update] BRANCH is not set. Please pass it as an argument to the make command. Example: BRANCH=main make update"; \
		exit 1; \
	fi
	@if [ -z "$(PACKAGES)" ]; then \
		echo "[ERROR] [Update] PACKAGES is empty. No packages to update."; \
		exit 1; \
	fi
	@devops-toolkit/backend/scripts/update_go_packages.sh
	@echo "[INFO] [Update] Done."

## Lists available targets
help: _help
 

