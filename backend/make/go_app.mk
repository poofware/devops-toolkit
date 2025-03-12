# -----------------------------
# Makefile for Go applications
#
# Include this Makefile in the root of your Go application to get access to common build targets.
# -----------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif


include devops-toolkit/backend/make/go_app_local.mk
# TODO: Add more targets here: go_app_deploy.mk, etc.

include devops-toolkit/shared/make/help.mk
help: _help
