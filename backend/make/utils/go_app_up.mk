# ----------------------
# Go App Up Target
# ----------------------

SHELL := /bin/bash

.PHONY: up

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_UP := 1


ifndef INCLUDED_GO_APP_DEPS
  include devops-toolkit/backend/make/utils/go_app_deps.mk
endif
ifndef INCLUDED_GO_APP_BUILD
  include devops-toolkit/backend/make/utils/go_app_build.mk
endif
ifndef INCLUDED_GO_APP_DOWN
  include devops-toolkit/backend/make/utils/go_app_down.mk
endif


_check-failed-services:
	@echo "[INFO] [Up] Checking exit status of '$(PROFILE_TO_CHECK)' containers..."
	@PROFILE_SERVICES="$$( $(COMPOSE_CMD) --profile $(PROFILE_TO_CHECK) config --services )"; \
	echo "[INFO] [Up] Found services: $$PROFILE_SERVICES"; \
	FAILED_SERVICES=""; \
	for svc in $$PROFILE_SERVICES; do \
	  EXIT_CODE=$$( $(COMPOSE_CMD) ps --format json --filter status=exited $$svc | jq -r '.ExitCode' ); \
	  if [ "$$EXIT_CODE" != "0" ] && [ "$$EXIT_CODE" != "" ]; then \
	    FAILED_SERVICES="$$FAILED_SERVICES $$svc(exit:$$EXIT_CODE)"; \
	  fi; \
	done; \
	if [ -n "$$FAILED_SERVICES" ]; then \
	  echo "[ERROR] [Up] The following '$(PROFILE_TO_CHECK)' service(s) exited with a non-zero exit code: $$FAILED_SERVICES"; \
	  exit 1; \
	else \
	  echo "[INFO] [Up] All '$(PROFILE_TO_CHECK)' services appear healthy (or none were launched)."; \
	fi

_db-up:
	@echo "[INFO] [Up] Starting any db services found matching the '$(COMPOSE_PROFILE_DB)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d && echo "[INFO] [Up] Done. Any db services found are up and running." || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d' failed (most likely no services found or already running). Ignoring..."

_migrate-up:
	@echo "[INFO] [Up] Starting any migration services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_MIGRATE) up && echo "[INFO] [Up] Done. Any migration services found are up and running." || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_MIGRATE) up' failed (no services found?). Ignoring..."

	@$(MAKE) _check-failed-services PROFILE_TO_CHECK=$(COMPOSE_PROFILE_MIGRATE)

_app-pre-up:
	@echo "[INFO] [Up] Starting any pre-start services found matching the '$(COMPOSE_PROFILE_APP_PRE)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_PRE) up -d && echo "[INFO] [Up] Done. Any pre-start services found are up and running." || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_PRE) up -d' failed (no services found?). Ignoring..."

_app-post-check-up:
	@echo "[INFO] [Up] Starting any post-start-check services found matching the '$(COMPOSE_PROFILE_APP_POST_CHECK)' profile..."
	@$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_POST_CHECK) up && echo "[INFO] [Up] Done. Any post-start-check services found are up and running." || \
		echo "[WARN] [Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_POST_CHECK) up' failed (no services found?). Ignoring..."

	@$(MAKE) _check-failed-services PROFILE_TO_CHECK=$(COMPOSE_PROFILE_APP_POST_CHECK)

## Starts services for all compose profiles in order (EXCLUDE_COMPOSE_PROFILE_APP to exclude app from 'up' - WITH_DEPS=1 to 'up' dependency services as well)
up: EXCLUDE_COMPOSE_PROFILE_APP ?= 0
up: EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK ?= 0
up: _deps-up
	@echo "[INFO] [Up] Running down target to ensure clean state..."
	@$(MAKE) down WITH_DEPS=0

	@echo "[INFO] [Up] Running build target..."
	@$(MAKE) build WITH_DEPS=0

	@echo "[INFO] [Up] Creating network '$(COMPOSE_NETWORK_NAME)'..."
	@docker network create $(COMPOSE_NETWORK_NAME) && \
		echo "[INFO] [Up] Network '$(COMPOSE_NETWORK_NAME)' successfully created." || \
		echo "[WARN] [Up] 'docker network create $(COMPOSE_NETWORK_NAME)' failed (network most likely already exists). Ignoring..."

	@$(MAKE) _db-up
	@$(MAKE) _migrate-up
	@$(MAKE) _app-pre-up

	@if [ "$(EXCLUDE_COMPOSE_PROFILE_APP)" -eq 1 ]; then \
	  echo "[INFO] [Up] Skipping app startup... EXCLUDE_COMPOSE_PROFILE_APP is set to 1"; \
	else \
	  echo "[INFO] [Up] Spinning up app..."; \
	  echo "[INFO] [Up] Finding free host port for app to bind to..."; \
	  export APP_HOST_PORT=$$(devops-toolkit/backend/scripts/find_available_port.sh 8080); \
	  echo "[INFO] [Up] Found free host port: $$APP_HOST_PORT"; \
	  $(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP) up -d; \
	  echo "[INFO] [Up] Done. $$APP_NAME is running on http://localhost:$$APP_HOST_PORT"; \
	fi

	@if [ "$(EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK)" -eq 1 ]; then \
	  echo "[INFO] [Up] Skipping app post-check... EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK is set to 1"; \
	else \
	  $(MAKE) _app-post-check-up; \
	fi

