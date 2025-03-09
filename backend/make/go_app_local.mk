# ------------------------------
#  Go App Local Testing Targets
#  
#  This Makefile is intended to be included in the main Makefile
#  in the root of a Go service.
# ------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif


####################################
# Runtime/Ci environment variables #
####################################
ifndef HCP_CLIENT_ID
  $(error HCP_CLIENT_ID is not set. Please define it in your runtime/ci environment. \
	Example: export HCP_CLIENT_ID="my_client_id")
endif

ifndef HCP_CLIENT_SECRET
  $(error HCP_CLIENT_SECRET is not set. Please define it in your runtime/ci environment. \
	Example: export HCP_CLIENT_SECRET="my_client_secret")
endif

ifndef HCP_TOKEN_ENC_KEY
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

ifndef WITH_DEPS
  $(error WITH_DEPS is not set. Please define it in your local Makefile or environment. \
	Example: WITH_DEPS=1)
endif

ifndef DEPS
  $(error DEPS is not set. Please define it in your local Makefile or environment. Define it empty if not needed. \
	Example: DEPS="/path/to/auth-service /path/to/worker-account-service" or DEPS="")
endif

###########################
# Root Makefile variables #
###########################
ifndef MIGRATIONS_PATH
  $(error MIGRATIONS_PATH is not set. Please define it in your local Makefile or environment. \
    Example: MIGRATIONS_PATH="migrations")
else
  $(if $(wildcard $(MIGRATIONS_PATH)),,$(error MIGRATIONS_PATH error: Directory '$(MIGRATIONS_PATH)' does not exist.))
endif

ifndef PACKAGES
  $(error PACKAGES is not set. Please define it in your local Makefile or environment. \
	Example: PACKAGES="go-middleware go-repositories go-utils go-models")
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
export PACKAGES := $(PACKAGES)

# For specific docker compose fields in our configuration
export APP_NAME := $(APP_NAME)
export APP_PORT := $(APP_PORT)
export MIGRATIONS_PATH := $(MIGRATIONS_PATH)
export ENV := $(ENV)
export HCP_ENCRYPTED_API_TOKEN ?= $(shell devops-toolkit/backend/scripts/fetch_hcp_token.sh encrypted)
export HCP_ORG_ID := a4c32123-5c1c-45cd-ad4e-9fe42a30d664
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


.PHONY: up integration-test unit-test down ci clean

# Include path relative to the root of the project
include devops-toolkit/backend/make/utils/go_app_deps.mk
include devops-toolkit/backend/make/utils/go_app_build.mk
include devops-toolkit/backend/make/utils/go_app_migrate.mk


## Starts db + app in background (make with DB_ONLY=1 to start only the db)
up: _deps-up
	@echo "[INFO] [Up] Running build target..."
	@$(MAKE) build WITH_DEPS=0
	@echo "[INFO] [Up] Creating shared service network..."
	@docker network create shared_service_network > /dev/null 2>&1 || \
		echo "[WARN] [Up] 'network create shared_service_network' failed (network most likely already exists) Ignoring..."

	@echo "[INFO] [Up] Creating shared volume 'shared_pgdata'..."
	@docker volume create shared_pgdata > /dev/null 2>&1 || \
		echo "[WARN] [Up] 'volume create shared_pgdata' failed (volume most likely already exists) Ignoring..."

	@echo "[INFO] [Up] Spinning up db..."
	@($(COMPOSE_CMD) up -d db > /dev/null 2>&1 && echo "[INFO] [Up] Database spun up successfully.") || \
	  echo "[WARN] [Up] '$(COMPOSE_CMD) up -d db' failed (container most likely already running) Ignoring..."

	@echo "[INFO] [Up] Running migrate target to make sure the db is up to date..."
	@$(MAKE) migrate

	@if [ "$(DB_ONLY)" = "1" ]; then \
	  echo "[INFO] [Up] DB_ONLY=1 set. Skipping app spin-up..."; \
	else \
	  echo "[INFO] [Up] Spinning up app..."; \
	  echo "[INFO] [Up] Finding free host port for app to bind to..."; \
	  export HOST_PORT=$$(devops-toolkit/backend/scripts/find_available_port.sh); \
	  echo "[INFO] [Up] Found free host port: $$HOST_PORT"; \
	  $(COMPOSE_CMD) up -d app; \
	  echo "[INFO] [Up] Done. $$APP_NAME is running on http://localhost:$$HOST_PORT"; \
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
integration-test: down up
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

## Shuts down all containers
down: _deps-down
	@echo "[INFO] [Down] Removing containers & volumes, keeping images..."
	$(COMPOSE_CMD) down -v --remove-orphans

	@echo "[INFO] [Down] Removing shared volume 'shared_pgdata'..."
	@docker volume rm shared_pgdata > /dev/null 2>&1 || \
		echo "[WARN] [Down] 'volume rm shared_pgdata' failed (volume most likely not found) Ignoring..."

	@echo "[INFO] [Down] Removing shared network 'shared_service_network'..."
	@docker network rm shared_service_network > /dev/null 2>&1 || \
		echo "[WARN] [Down] 'network rm shared_service_network' failed (network most likely already removed) Ignoring..."
	@echo "[INFO] [Down] Done."

## Cleans everything (containers, images, volumes)
clean: _deps-clean
	@echo "[INFO] [Clean] Running down target to stop all running containers..."
	@$(MAKE) down WITH_DEPS=0
	@echo "[INFO] [Clean] Full nuke of containers, images, volumes, networks..."
	$(COMPOSE_CMD) down --rmi local -v --remove-orphans
	@echo "[INFO] [Clean] Done."

## CI pipeline: Runs both integration and unit tests, and then shuts down all containers
ci:
	@echo "[INFO] [CI] Starting pipeline..."
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
	@devops-toolkit/backend/scripts/update_go_packages.sh
	@echo "[INFO] [Update] Done."

