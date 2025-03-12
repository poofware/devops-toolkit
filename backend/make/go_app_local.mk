# ------------------------------
# Go App Local Testing Targets
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

INCLUDED_GO_APP_LOCAL := 1


####################################
# Runtime/Ci environment variables #
####################################
ifneq ($(origin HCP_CLIENT_ID), environment)
  $(error HCP_CLIENT_ID is not set. Please define it in your runtime/ci environment. \
    Example: export HCP_CLIENT_ID="my_client_id")
endif

ifneq ($(origin HCP_CLIENT_SECRET), environment)
  $(error HCP_CLIENT_SECRET is not set. Please define it in your runtime/ci environment. \
    Example: export HCP_CLIENT_SECRET="my_client_secret")
endif

ifneq ($(origin HCP_TOKEN_ENC_KEY), environment)
  $(error HCP_TOKEN_ENC_KEY is not set. Please define it in your runtime/ci environment. \
    Example: export HCP_TOKEN_ENC_KEY="my_encryption_key")
endif

###################################################################
# Root Makefile variables, possibly overridden by the environment #
###################################################################
ifndef ENV
  $(error ENV is not set. Please define it in your local Makefile or environment. \
    Example: ENV=dev, Options: dev, dev-test, staging, staging-test, prod)
endif

ifndef APP_NAME
  $(error APP_NAME is not set. Please define it in your local Makefile or environment. \
	This variable should be unique to each go service. \
	Example: APP_NAME="my_project")
endif

ifndef APP_PORT
  $(error APP_PORT is not set. Please define it in your local Makefile or environment. \
	Example: APP_PORT=8080)
endif

ifndef COMPOSE_NETWORK_NAME
  $(error COMPOSE_NETWORK_NAME is not set. Please define it in your local Makefile or environment. \
	Example: COMPOSE_NETWORK_NAME="shared_service_network")
endif

ifndef WITH_DEPS
  $(error WITH_DEPS is not set. Please define it in your local Makefile or environment. \
	Example: WITH_DEPS=1)
endif

###########################
# Root Makefile variables #
###########################
ifneq ($(origin PACKAGES), file)
  $(error PACKAGES is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if your app has no dependency packages. \
    Example: export PACKAGES="go-middleware go-repositories go-utils go-models" or PACKAGES="")
endif

ifneq ($(origin DEPS), file)
  $(error DEPS is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if your app has no dependency apps. \
	Example: export DEPS="/path/to/auth-service /path/to/worker-account-service" or DEPS="")
endif

ifneq ($(origin COMPOSE_DB_NAME), file)
  $(error COMPOSE_DB_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if a db is not needed. \
	Example: export COMPOSE_DB_NAME="shared_pg_db" or COMPOSE_DB_NAME="")
endif

ifneq ($(origin MIGRATIONS_PATH), file)
  $(error MIGRATIONS_PATH is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if a db is not needed. \
	Example: export MIGRATIONS_PATH="migrations" or MIGRATIONS_PATH="")
endif

####################################
# Optional configuration variables #
####################################

### Env variable only variables ###
ifdef APP_URL
  ifeq ($(origin APP_URL), file)
    $(error APP_URL should be set as a runtime/ci environment variable, do not hardcode it in the root Makefile. \
  	  Example: export APP_URL="http://backend:8080")
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
export APP_URL
export COMPOSE_NETWORK_NAME
export COMPOSE_DB_NAME
ifdef COMPOSE_DB_NAME
  export COMPOSE_DB_VOLUME_NAME := $(COMPOSE_DB_NAME)_data
endif
export MIGRATIONS_PATH
export ENV
# To force a static assignment operation with '?=' behavior, we wrap the ':=' assignment in an ifndef check
ifndef HCP_ENCRYPTED_API_TOKEN
	export HCP_ENCRYPTED_API_TOKEN := $(shell devops-toolkit/backend/scripts/fetch_hcp_api_token.sh encrypted)
endif
# Poof
export HCP_ORG_ID := a4c32123-5c1c-45cd-ad4e-9fe42a30d664
# Backend
export HCP_PROJECT_ID := d413f61e-00f1-4ddf-afaf-bf8b9c04957e

# For docker compose
# List in order of dependency, separate by ':'
export COMPOSE_FILE := devops-toolkit/backend/docker/db.compose.yaml:devops-toolkit/backend/docker/go-app.compose.yaml

# For docker compose command options
COMPOSE_PROJECT_DIR := ./
COMPOSE_PROJECT_NAME := $(APP_NAME)

# Variable for app run/up/down docker compose commands
COMPOSE_CMD := docker compose \
		       --project-directory $(COMPOSE_PROJECT_DIR) \
			   -p $(COMPOSE_PROJECT_NAME)


# Include path relative to the root of the project
include devops-toolkit/backend/make/utils/go_app_deps.mk
include devops-toolkit/backend/make/utils/go_app_build.mk
include devops-toolkit/backend/make/utils/go_app_migrate.mk


## Starts db + app in background (make with DB_ONLY=1 to start only the db) (make with WITH_DEPS=1 to 'up' dependency services as well)
up: _deps-up
	@echo "[INFO] [Up] Running down target to ensure clean state..."
	@$(MAKE) down WITH_DEPS=0

	@echo "[INFO] [Up] Running build target..."
	@$(MAKE) build WITH_DEPS=0

	@echo "[INFO] [Up] Creating network '$(COMPOSE_NETWORK_NAME)'..."
	@docker network create $(COMPOSE_NETWORK_NAME) > /dev/null 2>&1 || \
		echo "[WARN] [Up] 'network create $(COMPOSE_NETWORK_NAME)' failed (network most likely already exists) Ignoring..."

	@if [ -n "$(COMPOSE_DB_NAME)" ]; then \
		echo "[INFO] [Up] Creating volume '$(COMPOSE_DB_VOLUME_NAME)'..."; \
		docker volume create $(COMPOSE_DB_VOLUME_NAME) > /dev/null 2>&1 || \
			echo "[WARN] [Up] 'volume create $(COMPOSE_DB_VOLUME_NAME)' failed (volume most likely already exists) Ignoring..."; \
		echo "[INFO] [Up] Spinning up db..."; \
		echo "[INFO] [Up] Finding free host port for db to bind to..."; \
		export COMPOSE_DB_HOST_PORT=$$(devops-toolkit/backend/scripts/find_available_port.sh 5432); \
		echo "[INFO] [Up] Found free host port: $$COMPOSE_DB_HOST_PORT"; \
		($(COMPOSE_CMD) up -d db > /dev/null 2>&1 && echo "[INFO] [Up] Database spun up successfully.") || \
			echo "[WARN] [Up] '$(COMPOSE_CMD) up -d db' failed (container most likely already running) Ignoring..."; \
		echo "[INFO] [Up] Done. $$COMPOSE_DB_NAME is running on port $$COMPOSE_DB_HOST_PORT"; \
		echo "[INFO] [Up] Running migrate target to make sure the db is up to date..."; \
		$(MAKE) migrate WITH_DEPS=0; \
	else \
		echo "[INFO] [Up] COMPOSE_DB_NAME not set. Skipping database and migration steps."; \
	fi

	@if [ "$(DB_ONLY)" = "1" ]; then \
	  echo "[INFO] [Up] DB_ONLY=1 set. Skipping app spin-up..."; \
	else \
	  echo "[INFO] [Up] Spinning up app..."; \
	  echo "[INFO] [Up] Finding free host port for app to bind to..."; \
	  export APP_HOST_PORT=$$(devops-toolkit/backend/scripts/find_available_port.sh 8080); \
	  echo "[INFO] [Up] Found free host port: $$APP_HOST_PORT"; \
	  $(COMPOSE_CMD) up -d app; \
	  echo "[INFO] [Up] Done. $$APP_NAME is running on http://localhost:$$APP_HOST_PORT"; \
	fi

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

## Shuts down all containers (make with WITH_DEPS=1 to 'down' dependency services as well)
down: _deps-down
	@echo "[INFO] [Down] Removing containers & volumes, keeping images..."
	$(COMPOSE_CMD) down -v --remove-orphans

	@echo "[INFO] [Down] Removing network '$(COMPOSE_NETWORK_NAME)'..."
	@docker network rm $(COMPOSE_NETWORK_NAME) > /dev/null 2>&1 || \
		echo "[WARN] [Down] 'network rm $(COMPOSE_NETWORK_NAME)' failed (network most likely already removed) Ignoring..."
	@echo "[INFO] [Down] Done."

	@if [ -n "$(COMPOSE_DB_NAME)" ]; then \
		echo "[INFO] [Down] Removing volume '$(COMPOSE_DB_VOLUME_NAME)'..."; \
		docker volume rm $(COMPOSE_DB_VOLUME_NAME) > /dev/null 2>&1 || \
			echo "[WARN] [Down] 'volume rm $(COMPOSE_DB_VOLUME_NAME)' failed (volume most likely not found) Ignoring..."; \
	fi

## Cleans everything (containers, images, volumes) (make with WITH_DEPS=1 to 'clean' dependency services as well)
clean: _deps-clean
	@echo "[INFO] [Clean] Running down target..."
	@$(MAKE) down WITH_DEPS=0
	@echo "[INFO] [Clean] Full nuke of containers, images, volumes, networks..."
	$(COMPOSE_CMD) down --rmi local -v --remove-orphans
	@echo "[INFO] [Clean] Done."

## CI pipeline: Runs both integration and unit tests, and then shuts down all containers
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

