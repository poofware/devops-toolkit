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


# Include path relative to the root of the project
include devops-toolkit/backend/make/utils/go_app_deps.mk


## Runs migrations in a one-off container
migrate: _deps-migrate
	@echo "[INFO] [Migrate] Migrating database..."; \
	$(COMPOSE_CMD) run --rm migrate
	@echo "[INFO] [Migrate] Database migrated."
