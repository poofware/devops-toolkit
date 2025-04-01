# ------------------------------
# Go App Configuration
# ------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif


INCLUDED_GO_APP_CONFIGURATION := 1

# ------------------------------
# Internal Variable Declarations
# ------------------------------

export GO_VERSION := 1.24


ifndef INCLUDED_APP_CONFIGURATION
  include devops-toolkit/backend/make/utils/app_configuration.mk
endif

