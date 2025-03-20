# ----------------------
# Go App Build Targets
# ----------------------

SHELL := /bin/bash

.PHONY: build

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_BUILD := 1


ifndef COMPOSE_PROJECT_NAME
  $(error COMPOSE_PROJECT_NAME is not set. Please define it in your local Makefile or environment. \
	This name should be unique to each go app. \
	Example: COMPOSE_PROJECT_NAME="auth-service")
endif

ifndef COMPOSE_PROJECT_DIR
  $(error COMPOSE_PROJECT_DIR is not set. Please define it in your local Makefile or environment. \
	This path evaluated should be unique to each go app. \
	Example: COMPOSE_PROJECT_DIR="./")
endif

ifndef COMPOSE_PROFILE_FLAGS
  $(error COMPOSE_PROFILE_FLAGS is not set. Please define it in your local Makefile or environment. \
	Example: COMPOSE_PROFILE_FLAGS="--profile app_default")
endif


SSH_DOCKER_BUILD_CMD := devops-toolkit/backend/scripts/ssh_docker_build.sh compose \
						--project-directory $(COMPOSE_PROJECT_DIR) \
						-p $(COMPOSE_PROJECT_NAME) \
						$(COMPOSE_PROFILE_FLAGS)


# Include path relative to the root of the project
include devops-toolkit/backend/make/utils/go_app_deps.mk


## Builds Docker images for services found in COMPOSE_FILE matching specified profile flags (make with BUILD_SERVICES to build specific services)
build: _deps-build
	@if [ -n "$(BUILD_SERVICES)" ]; then \
		echo "[INFO] [Build] Building Docker images for services: $(BUILD_SERVICES)..."; \
	else \
		echo "[INFO] [Build] Building all services with profiles: $(COMPOSE_PROFILE_FLAGS)..."; \
	fi
	$(SSH_DOCKER_BUILD_CMD) build $(BUILD_SERVICES)
	@echo "[INFO] [Build] Done."
