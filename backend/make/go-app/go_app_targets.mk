# ------------------------------
# Go App Targets
# ------------------------------

SHELL := /bin/bash

.PHONY: help build

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP_TARGETS := 1


# --------------------------------
# External Variable Validation
# --------------------------------

# Root Makefile variables #

ifneq ($(origin PACKAGES), file)
  $(error PACKAGES is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Define it empty if your app has no dependency packages. \
    Example: PACKAGES="go-middleware go-repositories go-compose go-models" or PACKAGES="")
endif


# --------------------------------
# Internal Variable Declaration
# --------------------------------
export GO_VERSION := 1.24
export PACKAGES


# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_GO_APP_UPDATE
  include devops-toolkit/backend/make/go-app/go_app_update.mk
endif
ifndef INCLUDED_COMPOSE_BUILD
  include devops-toolkit/backend/make/compose/compose_build.mk
endif
ifndef INCLUDED_VENDOR
  include devops-toolkit/backend/make/utils/vendor.mk
endif
ifndef INCLUDED_HELP
  include devops-toolkit/shared/make/help.mk
endif

build:: vendor

help::
	@echo "--------------------------------------------------"
	@echo "[INFO] Go App Configuration variables:"
	@echo "--------------------------------------------------"
	@echo "APP_NAME: $(APP_NAME)"
	@echo "APP_PORT: $(APP_PORT)"
	@echo "PACKAGES: $(PACKAGES)"
	@echo "APP_URL_FROM_COMPOSE_NETWORK: $(APP_URL_FROM_COMPOSE_NETWORK)"
	@echo "APP_URL_FROM_ANYWHERE: $(APP_URL_FROM_ANYWHERE)"
	@echo "--------------------------------------------------"
	@echo
