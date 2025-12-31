# ------------------------------
# Compose Rust App Targets
# ------------------------------

SHELL := /bin/bash

.PHONY: help cargo-build cargo-check cargo-test cargo-fmt cargo-clippy run run-release

# Check that the current working directory is the root of a Rust service by verifying that Cargo.toml exists.
ifeq ($(wildcard Cargo.toml),)
  $(error Error: Cargo.toml not found. Please ensure you are in the root directory of your Rust service.)
endif

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef INCLUDED_COMPOSE_RUST_APP_CONFIGURATION
  $(error [ERROR] [Compose Rust App Targets] The Compose Rust App Configuration must be included before any Compose Rust App Targets.)
endif

ifdef INCLUDED_COMPOSE_APP_TARGETS
  $(error [ERROR] [Compose Rust App Targets] The Compose App Targets must not be included before this file. \
	This file includes the Compose App Targets, which are required for the Compose Rust App Targets.)
endif


# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_COMPOSE_APP_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-configurations/compose-file-configurations/app/compose_app_targets.mk
endif


## Build Rust binary locally (release mode)
cargo-build:
	@echo "[INFO] [Cargo Build] Building Rust binary in $(RUST_BUILD_PROFILE) mode..."
	@echo "[INFO] [Cargo Build] Flags: $(RUSTFLAGS)"
	@cargo build --$(RUST_BUILD_PROFILE)
	@echo "[INFO] [Cargo Build] Done."

## Run cargo check
cargo-check:
	@echo "[INFO] [Cargo Check] Running cargo check..."
	@cargo check
	@echo "[INFO] [Cargo Check] Done."

## Run cargo test
cargo-test:
	@echo "[INFO] [Cargo Test] Running tests..."
	@cargo test
	@echo "[INFO] [Cargo Test] Done."

## Run cargo fmt
cargo-fmt:
	@echo "[INFO] [Cargo Fmt] Formatting code..."
	@cargo fmt
	@echo "[INFO] [Cargo Fmt] Done."

## Run cargo clippy
cargo-clippy:
	@echo "[INFO] [Cargo Clippy] Running clippy lints..."
	@cargo clippy -- -D warnings
	@echo "[INFO] [Cargo Clippy] Done."

## Run the server locally (foreground, debug mode)
run:
	@echo "[INFO] [Run] Starting Rust server on port $(APP_PORT)..."
	@PORT=$(APP_PORT) cargo run

## Run the server in release mode locally (foreground)
run-release:
	@echo "[INFO] [Run Release] Starting Rust server (release) on port $(APP_PORT)..."
	@PORT=$(APP_PORT) cargo run --release

help::
	@echo "--------------------------------------------------"
	@echo "[INFO] Rust App Configuration variables:"
	@echo "--------------------------------------------------"
	@echo "APP_NAME: $(APP_NAME)"
	@echo "APP_PORT: $(APP_PORT)"
	@echo "LOG_LEVEL: $(LOG_LEVEL)"
	@echo "RUST_BINARY_NAME: $(RUST_BINARY_NAME)"
	@echo "RUST_VERSION: $(RUST_VERSION)"
	@echo "RUST_BUILD_PROFILE: $(RUST_BUILD_PROFILE)"
	@echo "APP_URL_FROM_COMPOSE_NETWORK: $(APP_URL_FROM_COMPOSE_NETWORK)"
	@echo "APP_URL_FROM_ANYWHERE: $(APP_URL_FROM_ANYWHERE)"
	@echo "--------------------------------------------------"
	@echo


INCLUDED_COMPOSE_RUST_APP_TARGETS := 1
