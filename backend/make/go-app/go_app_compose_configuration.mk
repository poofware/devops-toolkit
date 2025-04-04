# ------------------------------
# Go App Configuration
# ------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP_CONFIGURATION := 1

ifndef INCLUDED_COMPOSE_PROJECT_CONFIGURATION
  $(error [ERROR] [Go App Compose Configuration] The Compose Project Configuration must be included before any compose file configuration. \
	Include devops-toolkit/backend/make/compose/compose_project_configuration.mk in your root Makefile.)
endif


# --------------------------------
# External Variable Validation
# --------------------------------

ifdef LOG_LEVEL
  ifeq ($(origin LOG_LEVEL), file)
    $(error LOG_LEVEL override should be set as a runtime/ci environment variable, do not hardcode it in the root Makefile. \
	  Example: LOG_LEVEL=debug make up)
  endif
endif


# ------------------------------
# Internal Variable Declarations
# ------------------------------

export GO_VERSION := 1.24
export LOG_LEVEL ?= info
export DEPS_VAR_PASSTHROUGH += LOG_LEVEL


ifndef INCLUDED_APP_CONFIGURATION
  include devops-toolkit/backend/make/utils/app_compose_configuration.mk
endif

