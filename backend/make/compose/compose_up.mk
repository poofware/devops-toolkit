# ----------------------
# Compose Up Target
# ----------------------

SHELL := /bin/bash

.PHONY: up _up-db _up-migrate _up-app-pre _up-app-post-check 

# Check that the current working directory is the root of a project by verifying that the root Makefile exists.
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

INCLUDED_COMPOSE_UP := 1


ifndef INCLUDED_COMPOSE_DEPS
  include devops-toolkit/backend/make/compose/compose_deps.mk
endif
ifndef INCLUDED_COMPOSE_BUILD
  include devops-toolkit/backend/make/compose/compose_build.mk
endif
ifndef INCLUDED_COMPOSE_DOWN
  include devops-toolkit/backend/make/compose/compose_down.mk
endif
ifndef INCLUDED_COMPOSE_SERVICE_UTILS
  include devops-toolkit/backend/make/compose/compose_service_compose.mk
endif


_up-db:
	@if [ -z "$(COMPOSE_PROFILE_DB_SERVICES)" ]; then \
		echo "[WARN] [Up-DB] No services found matching the '$(COMPOSE_PROFILE_DB)' profile. Skipping..."; \
	else \
		echo "[INFO] [Up-DB] Starting any database services found matching the '$(COMPOSE_PROFILE_DB)' profile..."; \
		echo "[INFO] [Up-DB] Found services: $(COMPOSE_PROFILE_DB_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d && echo "[INFO] [Up-DB] Done. Any '$(COMPOSE_PROFILE_DB)' services found are up and running." || \
			echo "[WARN] [Up-DB] '$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_DB) up -d' failed (most likely already running). Ignoring..."; \
	fi

_up-migrate:
	@if [ -z "$(COMPOSE_PROFILE_MIGRATE_SERVICES)" ]; then \
		echo "[WARN] [Up-Migrate] No services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile. Skipping..."; \
	else \
		echo "[INFO] [Up-Migrate] Starting any migration services found matching the '$(COMPOSE_PROFILE_MIGRATE)' profile..."; \
		echo "[INFO] [Up-Migrate] Found services: $(COMPOSE_PROFILE_MIGRATE_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_MIGRATE) up; \
		echo "[INFO] [Up-Migrate] Done. Any '$(COMPOSE_PROFILE_MIGRATE)' services found were run."; \
		$(MAKE) _check-failed-services --no-print-directory PROFILE_TO_CHECK=$(COMPOSE_PROFILE_MIGRATE) SERVICES_TO_CHECK="$(COMPOSE_PROFILE_MIGRATE_SERVICES)"; \
	fi

_up-app-pre:
	@if [ -z "$(COMPOSE_PROFILE_APP_PRE_SERVICES)" ]; then \
		echo "[WARN] [Up-App-Pre] No services found matching the '$(COMPOSE_PROFILE_APP_PRE)' profile. Skipping..."; \
	else \
		echo "[INFO] [Up-App-Pre] Starting any app pre-start services found matching the '$(COMPOSE_PROFILE_APP_PRE)' profile..."; \
		echo "[INFO] [Up-App-Pre] Found services: $(COMPOSE_PROFILE_APP_PRE_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_PRE) up -d; \
		echo "[INFO] [Up-App-Pre] Done. Any '$(COMPOSE_PROFILE_APP_PRE)' services found are up and running."; \
	fi

_up-app-post-check:
	@if [ -z "$(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)" ]; then \
		echo "[WARN] [Up-App-Post-Check] No services found matching the '$(COMPOSE_PROFILE_APP_POST_CHECK)' profile. Skipping..."; \
	else \
		echo "[INFO] [Up-App-Post-Check] Starting any app post-start check services found matching the '$(COMPOSE_PROFILE_APP_POST_CHECK)' profile..."; \
		echo "[INFO] [Up-App-Post-Check] Found services: $(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)"; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_POST_CHECK) up; \
		echo "[INFO] [Up-App-Post-Check] Done. Any '$(COMPOSE_PROFILE_APP_POST_CHECK)' services found were run."; \
		$(MAKE) _check-failed-services --no-print-directory PROFILE_TO_CHECK=$(COMPOSE_PROFILE_APP_POST_CHECK) SERVICES_TO_CHECK="$(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES)"; \
	fi

_app-up:
	@if [ -z "$(COMPOSE_PROFILE_APP_SERVICES)" ]; then \
		echo "[ERROR] [Up-App] No services found matching the '$(COMPOSE_PROFILE_APP)' profile!"; \
	else \
		echo "[INFO] [Up-App] Starting app services found matching the '$(COMPOSE_PROFILE_APP)' profile..."; \
		echo "[INFO] [Up-App] Found services: $(COMPOSE_PROFILE_APP_SERVICES)"; \
		echo "[INFO] [Up-App] Spinning up app..."; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP) up -d; \
		echo "[INFO] [Up-App] Done. $$APP_NAME is running on http://localhost:$$APP_HOST_PORT"; \
	fi

## Starts services for all compose profiles in order (EXCLUDE_COMPOSE_PROFILE_APP=1 to exclude profile 'app' from 'up' - EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK=1 to exclude profile 'app_post_check' from 'up' - WITH_DEPS=1 to 'up' dependency projects as well)
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

	@$(MAKE) _up-db --no-print-directory
	@$(MAKE) _up-migrate --no-print-directory
	@$(MAKE) _up-app-pre --no-print-directory

	@if [ "$(EXCLUDE_COMPOSE_PROFILE_APP)" -eq 1 ]; then \
		echo "[INFO] [Up] Skipping app startup... EXCLUDE_COMPOSE_PROFILE_APP is set to 1"; \
	else \
		$(MAKE) _app-up --no-print-directory; \
	fi

	@if [ "$(EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK)" -eq 1 ]; then \
	  echo "[INFO] [Up] Skipping app post-check... EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK is set to 1"; \
	else \
	  $(MAKE) _up-app-post-check --no-print-directory; \
	fi

