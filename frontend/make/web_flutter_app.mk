# --------------------------------
# Mobile Flutter App
# --------------------------------

SHELL := /bin/bash

.PHONY: run-web \
	build-web \
	e2e-test-web \
	integration-test-web \
	ci-web

# --------------------------------
# Internal Variable Declaration
# --------------------------------

ifndef INCLUDED_FLUTTER_APP_CONFIGURATION
  include devops-toolkit/frontend/make/utils/flutter_app_configuration.mk
endif

# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_FLUTTER_APP_TARGETS
  include devops-toolkit/frontend/make/utils/flutter_app_targets.mk
endif

# Run API integration tests (non-UI logic tests) for Web
integration-test-web:
	@$(MAKE) _integration-test --no-print-directory PLATFORM=web

# Run end-to-end (UI) tests for Web
e2e-test-web:
	@$(MAKE) _e2e-test --no-print-directory PLATFORM=web

## Run the app in a specific environment (ENV=dev|dev-test|staging|prod) for web
run-web:
	@$(MAKE) _run --no-print-directory PLATFORM=web

## Build command for Web (production, release mode)
build-web: logs
	@if [ "$(ENV)" = "$(PROD_ENV)" ]; then \
		eval "$$($(MAKE) _export_current_backend_domain --no-print-directory)" && \
		echo "[INFO] [Build Web] Building..."; \
		flutter build web --target lib/main/main_prod.dart $(VERBOSE_FLAG) 2>&1 | tee logs/build_web.log; \
	else \
		echo "[ERROR] [Build Web] Skipping Web build for ENV=$(ENV). Only ENV=$(PROD_ENV) is allowed."; \
		exit 1; \
	fi

## CI Web pipeline: Starts backend, runs both integration and e2e tests, and then shuts down backend
ci-web::
	@echo "[INFO] [CI] Starting pipeline..."
	@echo "[INFO] [CI] Calling 'down-backend' target to ensure clean state..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Calling 'integration-test-web' target..."
	@$(MAKE) integration-test-web --no-print-directory AUTO_LAUNCH_BACKEND=1
	@# $(MAKE) e2e-test-web --no-print-directory # TODO: implement e2e tests
	@echo "[INFO] [CI] Calling 'down-backend' target..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Pipeline complete."


INCLUDED_WEB_FLUTTER_APP := 1
