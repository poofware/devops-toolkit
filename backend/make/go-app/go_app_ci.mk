# -----------------------
# Go App CI Target
# -----------------------

SHELL := /bin/bash

.PHONY: ci

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_CI := 1


ifndef INCLUDED_GO_APP_UP
  include devops-toolkit/backend/make/go-app/go_app_up.mk
endif
ifndef INCLUDED_GO_APP_TEST
  include devops-toolkit/backend/make/go-app/go_app_test.mk
endif
ifndef INCLUDED_GO_APP_DOWN
  include devops-toolkit/backend/make/go-app/go_app_down.mk
endif


## CI pipeline: Starts services, runs both integration and unit tests, and then shuts down all containers
ci:
	@echo "[INFO] [CI] Starting pipeline..."
	$(MAKE) up --no-print-directory
	$(MAKE) integration-test --no-print-directory
	@# $(MAKE) unit-test  # TODO: implement unit tests
	$(MAKE) down --no-print-directory
	@echo "[INFO] [CI] Pipeline complete."


