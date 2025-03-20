# ------------------------
# Go App Migrate Targets
# ------------------------

SHELL := /bin/bash

.PHONY: migrate

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP_MIGRATE := 1


ifndef MIGRATIONS_PATH
  $(error MIGRATIONS_PATH is not set. Please define it in your local Makefile or environment. Define it empty if a db is not needed. \
	Example: MIGRATIONS_PATH="migrations" or MIGRATIONS_PATH="")
endif

ifndef COMPOSE_PROJECT_NAME
  $(error COMPOSE_PROJECT_NAME is not set. Please define it in your local Makefile or environment. \
	This variable should be unique to each go service. \
	Example: COMPOSE_PROJECT_NAME="auth-service")
endif

ifndef COMPOSE_PROJECT_DIR
  $(error COMPOSE_PROJECT_DIR is not set. Please define it in your local Makefile or environment. \
	This variable should be unique to each go service. \
	Example: COMPOSE_PROJECT_DIR="./")
endif


export MIGRATIONS_PATH

COMPOSE_CMD := docker compose \
		       --project-directory $(COMPOSE_PROJECT_DIR) \
			   -p $(COMPOSE_PROJECT_NAME)


# Include path relative to the root of the project
include devops-toolkit/backend/make/utils/go_app_deps.mk


## Runs migrations in a one-off container
migrate: _deps-migrate
	@if [ -n "$(MIGRATIONS_PATH)" ]; then \
	    echo "[INFO] [Migrate] Migrating database..."; \
	    $(COMPOSE_CMD) run --rm migrate; \
	    echo "[INFO] [Migrate] Database migrated."; \
	else \
	    echo "[ERROR] [Migrate] MIGRATIONS_PATH is empty. No migrations to run."; \
		exit 1; \
	fi

