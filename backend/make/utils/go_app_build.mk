# ----------------------
# Go App Build Targets
# ----------------------

SHELL := /bin/bash

.PHONY: build

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP_BUILD := 1


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

SSH_DOCKER_BUILD_CMD := devops-toolkit/backend/scripts/ssh_docker_build.sh compose \
						--project-directory $(COMPOSE_PROJECT_DIR) \
						-p $(COMPOSE_PROJECT_NAME)

# Default services to build for the application (app and its runtime dependencies)
DEFAULT_BUILD_SERVICES := app db migrate

# Allow overriding services via SERVICES variable (e.g., make build SERVICES="app db unit-test")
BUILD_SERVICES ?= $(DEFAULT_BUILD_SERVICES)


# Include path relative to the root of the project
ifndef INCLUDED_GO_APP_DEPS
  include devops-toolkit/backend/make/utils/go_app_deps.mk
endif


## Builds specified Docker images (defaults to app, db, migrate) found in COMPOSE_FILE (make with VERBOSE=1 for more info)
build: _deps-build
	@echo "[INFO] [Build] Building Docker images for services: $(BUILD_SERVICES)..."
	$(SSH_DOCKER_BUILD_CMD) build $(BUILD_SERVICES)
	@echo "[INFO] [Build] Done."
