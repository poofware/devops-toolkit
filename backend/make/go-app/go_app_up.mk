# ----------------------
# Go App Up Target
# ----------------------

SHELL := /bin/bash

.PHONY: up _db-up _migrate-up _app-pre-up _app-post-check-up

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_UP := 1


ifndef INCLUDED_GO_APP_DEPS
  include devops-toolkit/backend/make/go-app/go_app_deps.mk
endif
ifndef INCLUDED_GO_APP_BUILD
  include devops-toolkit/backend/make/go-app/go_app_build.mk
endif
ifndef INCLUDED_GO_APP_DOWN
  include devops-toolkit/backend/make/go-app/go_app_down.mk
endif
ifndef INCLUDED_COMPOSE_SERVICE_UTILS
  include devops-toolkit/backend/make/utils/compose_service_utils.mk
endif


_db-up:
	@if [ -z "$(COMPOSE_PROFILE_DB_SERVICES)" ]; then \
		echo "[WARN] [DB-Up] No services found matching the '$(COMPOSE_PROFILE_DB)' profile. Skipping..."; \
	else \
		echo "[INFO] [DB-Up] Starting any database services found matching the '$(COMPOSE_PROFILE_DB)' profile..."; \
		echo "[INFO] [DB-Up] Found services: $(COMPOSE_PROFILE_DB_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d && echo "[INFO] [DB-Up] Done. Any '$(COMPOSE_PROFILE_DB)' services found are up and running." || \
			echo "[WARN] [DB-Up] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d' failed (most likely already running). Ignoring..."; \
	fi

_migrate-up:
	@if [ -z "$(COMPOSE_PROFILE_MIGRATE_SERVICES)" ]; then \
		echo "[WARN] [Migrate-Up] No services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile. Skipping..."; \
	else \
		echo "[INFO] [Migrate-Up] Starting any migration services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile..."; \
		echo "[INFO] [Migrate-Up] Found services: $(COMPOSE_PROFILE_MIGRATE_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_MIGRATE) up; \
		echo "[INFO] [Migrate-Up] Done. Any '$(COMPOSE_PROFILE_MIGRATE)' services found were run."; \
		$(MAKE) _check-failed-services --no-print-directory PROFILE_TO_CHECK=$(COMPOSE_PROFILE_MIGRATE) SERVICES_TO_CHECK="$(COMPOSE_PROFILE_MIGRATE_SERVICES)"; \
	fi

_app-pre-up:
	@if [ -z "$(COMPOSE_PROFILE_APP_PRE_SERVICES)" ]; then \
		echo "[WARN] [App-Pre-Up] No services found matching the '$(COMPOSE_PROFILE_APP_PRE)' profile. Skipping..."; \
	else \
		echo "[INFO] [App-Pre-Up] Starting any app pre-start services found matching the '$(COMPOSE_PROFILE_APP_PRE)' profile..."; \
		echo "[INFO] [App-Pre-Up] Found services: $(COMPOSE_PROFILE_APP_PRE_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_PRE) up -d; \
		echo "[INFO] [App-Pre-Up] Done. Any '$(COMPOSE_PROFILE_APP_PRE)' services found are up and running."; \
	fi

_app-post-check-up:
	@if [ -z "$(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)" ]; then \
		echo "[WARN] [App-Post-Check-Up] No services found matching the '$(COMPOSE_PROFILE_APP_POST_CHECK)' profile. Skipping..."; \
	else \
		echo "[INFO] [App-Post-Check-Up] Starting any app post-start check services found matching the '$(COMPOSE_PROFILE_APP_POST_CHECK)' profile..."; \
		echo "[INFO] [App-Post-Check-Up] Found services: $(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_POST_CHECK) up; \
		echo "[INFO] [App-Post-Check-Up] Done. Any '$(COMPOSE_PROFILE_APP_POST_CHECK)' services found were run."; \
		$(MAKE) _check-failed-services --no-print-directory PROFILE_TO_CHECK=$(COMPOSE_PROFILE_APP_POST_CHECK) SERVICES_TO_CHECK="$(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)"; \
	fi

_app-up:
	@if [ -z "$(COMPOSE_PROFILE_APP_SERVICES)" ]; then \
		echo "[ERROR] [App-Up] No services found matching the '$(COMPOSE_PROFILE_APP)' profile!"; \
	else \
		echo "[INFO] [App-Up] Starting app services found matching the '$(COMPOSE_PROFILE_APP)' profile..."; \
		echo "[INFO] [App-Up] Found services: $(COMPOSE_PROFILE_APP_SERVICES)"; \
		echo "[INFO] [App-Up] Spinning up app..."; \
		echo "[INFO] [App-Up] Finding free host port for app to bind to..."; \
		export APP_HOST_PORT=$$(devops-toolkit/backend/scripts/find_available_port.sh 8080); \
		echo "[INFO] [App-Up] Found free host port: $$APP_HOST_PORT"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP) up -d; \
		echo "[INFO] [App-Up] Done. $$APP_NAME is running on http://localhost:$$APP_HOST_PORT"; \
	fi

## Starts services for all compose profiles in order (EXCLUDE_COMPOSE_PROFILE_APP=1 to exclude profile 'app' from 'up' - EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK=1 to exclude profile 'app_post_check' from 'up' - WITH_DEPS=1 to 'up' dependency services as well)
up: EXCLUDE_COMPOSE_PROFILE_APP ?= 0
up: EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK ?= 0
up: _deps-up
	@echo "[INFO] [Up] Running down target to ensure clean state..."
	@$(MAKE) down --no-print-directory WITH_DEPS=0

	@echo "[INFO] [Up] Running build target..."
	@$(MAKE) build --no-print-directory WITH_DEPS=0

	@echo "[INFO] [Up] Creating network '$(COMPOSE_NETWORK_NAME)'..."
	@docker network create $(COMPOSE_NETWORK_NAME) && \
		echo "[INFO] [Up] Network '$(COMPOSE_NETWORK_NAME)' successfully created." || \
		echo "[WARN] [Up] 'docker network create $(COMPOSE_NETWORK_NAME)' failed (network most likely already exists). Ignoring..."

	@$(MAKE) _db-up --no-print-directory
	@$(MAKE) _migrate-up --no-print-directory
	@$(MAKE) _app-pre-up --no-print-directory

	@if [ "$(EXCLUDE_COMPOSE_PROFILE_APP)" -eq 1 ]; then \
		echo "[INFO] [Up] Skipping app startup... EXCLUDE_COMPOSE_PROFILE_APP is set to 1"; \
	else \
		$(MAKE) _app-up --no-print-directory; \
	fi

	@if [ "$(EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK)" -eq 1 ]; then \
	  echo "[INFO] [Up] Skipping app post-check... EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK is set to 1"; \
	else \
	  $(MAKE) _app-post-check-up --no-print-directory; \
	fi

