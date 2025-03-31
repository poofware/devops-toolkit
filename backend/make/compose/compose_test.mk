# ----------------------
# Compose Test Targets
# ----------------------

SHELL := /bin/bash

.PHONY: integration-test unit-test

# Check that the current working directory is the root of a project by verifying that the root Makefile exists.
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

INCLUDED_COMPOSE_TEST := 1


ifndef INCLUDED_COMPOSE_BUILD
  include devops-toolkit/backend/make/compose/compose_build.mk
endif
ifndef INCLUDED_COMPOSE_SERVICE_UTILS
  include devops-toolkit/backend/make/compose/compose_service_compose.mk
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
		echo "[INFO] [Integration Test] Calling 'build' target for integration-test service exclusively..."; \
		$(MAKE) build --no-print-directory COMPOSE_BUILD_BASE_SERVICES="$(COMPOSE_PROFILE_BASE_APP_INTEGRATION_TEST_SERVICES)" COMPOSE_BUILD_SERVICES="$(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)" WITH_DEPS=0; \
		echo "[INFO] [Integration Test] Starting any integration test services found matching the '$(COMPOSE_PROFILE_APP_INTEGRATION_TEST)' profile..."; \
		echo "[INFO] [Integration Test] Found services: $(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)"; \
		echo "[INFO] [Integration Test] Starting..."; \
		$(COMPOSE_CMD) up $(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES) || exit 1; \
		echo "[INFO] [Integration Test] Done. Any '$(COMPOSE_PROFILE_APP_INTEGRATION_TEST)' services found were run."; \
		$(MAKE) _check-failed-services --no-print-directory \
			PROFILE_TO_CHECK=$(COMPOSE_PROFILE_APP_INTEGRATION_TEST) \
			SERVICES_TO_CHECK="$(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES)" \
		&& \
			echo "[INFO] [Integration Test] Completed successfully!" \
		|| \
			{ \
				echo ""; \
				echo "[ERROR] [Integration Test] FAILED. Collecting logs..."; \
				$(COMPOSE_CMD) logs $(COMPOSE_PROFILE_DB_SERVICES) $(COMPOSE_PROFILE_APP_SERVICES); \
				exit 1; \
			}; \
	fi
