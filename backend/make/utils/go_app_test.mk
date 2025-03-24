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
	@echo "[INFO] [Integration Test] Running build target for integration-test service exclusively..."
	@$(MAKE) build BUILD_SERVICES="integration-test" WITH_DEPS=0
	@echo "[INFO] [Integration Test] Starting...";
	@if ! $(COMPOSE_CMD) run --rm integration-test; then \
	  echo ""; \
	  echo "[ERROR] [Integration Test] FAILED. Collecting logs..."; \
	  $(COMPOSE_CMD) logs db app; \
	  exit 1; \
	fi
	@echo "[INFO] [Integration Test] Completed successfully!"

