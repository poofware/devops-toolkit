# ------------------------------
# Compose Rust App Configuration
# ------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a Rust service by verifying that Cargo.toml exists.
ifeq ($(wildcard Cargo.toml),)
  $(error Error: Cargo.toml not found. Please ensure you are in the root directory of your Rust service.)
endif

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef INCLUDED_COMPOSE_PROJECT_CONFIGURATION
  $(error [ERROR] [Compose Rust App Configuration] The Compose Project Configuration must be included before any compose file configuration. \
	Include $$(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-configurations/compose_project_configuration.mk in your root Makefile.)
endif

ifdef INCLUDED_COMPOSE_APP_CONFIGURATION
  $(error [ERROR] [Compose Rust App Configuration] The Compose App Configuration must not be included before this file. \
	This file includes the Compose App Configuration, which is required for the Compose Rust App Configuration.)
endif


# --------------------------------
# External Variable Validation
# --------------------------------

# Root Makefile variables #

ifneq ($(origin RUST_BINARY_NAME), file)
  $(error RUST_BINARY_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Example: RUST_BINARY_NAME="mazle-generator")
endif


# ------------------------------
# Internal Variable Declarations
# ------------------------------

# Rust version for the Docker image
export RUST_VERSION ?= 1.83

# The name of the binary to build
export RUST_BINARY_NAME

# Release profile (debug or release)
export RUST_BUILD_PROFILE ?= release

ifndef INCLUDED_COMPOSE_APP_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-configurations/compose-file-configurations/app/compose_app_configuration.mk
endif


INCLUDED_COMPOSE_RUST_APP_CONFIGURATION := 1
