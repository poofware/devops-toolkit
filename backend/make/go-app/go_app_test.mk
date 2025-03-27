# ----------------------
# Go App Test Targets
# ----------------------

SHELL := /bin/bash

.PHONY: integration-test unit-test

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_TEST := 1


ifndef INCLUDED_GO_APP_BUILD
  include devops-toolkit/backend/make/utils/go_app_build.mk
endif
ifndef INCLUDED_COMPOSE_SERVICE_UTILS
  include devops-toolkit/backend/make/utils/compose_service_utils.mk
endif


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
	@if [ -z "$(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)" ]; then \
		echo "[WARN] [Integration Test] No services found matching the '$(COMPOSE_PROFILE_APP_INTEGRATION_TEST)' profile. Skipping..."; \
	else \
		echo "[INFO] [Integration Test] Running build target for integration-test service exclusively..."; \
		$(MAKE) build --no-print-directory BUILD_SERVICES="$(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)" WITH_DEPS=0; \
		echo "[INFO] [Integration Test] Starting any integration test services found matching the '$(COMPOSE_PROFILE_APP_INTEGRATION_TEST)' profile..."; \
		echo "[INFO] [Integration Test] Found services: $(COMPOSE_PROFILE_MIGRATE_SERVICES)"; \
		echo "[INFO] [Integration Test] Starting..."; \
		$(COMPOSE_CMD) --profile $(COMPOSE_PROFILE_APP_INTEGRATION_TEST) up; \
		echo "[INFO] [Integration Test] Done. Any '$(COMPOSE_PROFILE_APP_INTEGRATION_TEST)' services found were run."; \
		$(MAKE) _check-failed-services --no-print-directory PROFILE_TO_CHECK=$(COMPOSE_PROFILE_APP_INTEGRATION_TEST) SERVICES_TO_CHECK="$(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)" && \
		echo "[INFO] [Integration Test] Completed successfully!" || \
			echo ""; \
			echo "[ERROR] [Integration Test] FAILED. Collecting logs..."; \
			$(COMPOSE_CMD) logs $(COMPOSE_PROFILE_DB_SERVICES) $(COMPOSE_PROFILE_APP_SERVICES); \
			exit 1; \
	fi
