# --------------------------------
# Makefile for Flutter App
# --------------------------------

SHELL := /bin/bash

.PHONY: check clean down-backend up-backend clean-backend \
	run-ios run-android build-ios build-android \
	e2e-test-ios e2e-test-android \
	integration-test-ios integration-test-android \
	_integration-test _e2e-test _run-env _run


# ------------------------------
# External Variable Validation
# ------------------------------

# Root Makefile variables #

ifneq ($(origin APP_NAME), file)
  $(error APP_NAME is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Example: APP_NAME="account-service")
endif

ifneq ($(origin BACKEND_GATEWAY_PATH), file)
  $(error BACKEND_GATEWAY_PATH is either not set or set as a runtime/ci environment variable, should be hardcoded in the root Makefile. \
	Example: BACKEND_GATEWAY_PATH="../meta-service")
endif


# ------------------------------
# Internal Variable Declaration
# ------------------------------ 

ifndef INCLUDED_ENV_CONFIGURATION
  include devops-toolkit/shared/make/utils/env_configuration.mk
endif

LOG_LEVEL ?= info

export HCP_APP_NAME := $(APP_NAME)

VERBOSE ?= 0
VERBOSE_FLAG := $(if $(filter 1,$(VERBOSE)),--verbose,)

# -------------------------------------------------
# Macro: run_command_with_backend
#
# Runs a command with the backend up if AUTO_LAUNCH_BACKEND=1.
# Otherwise, runs the command directly.
# Note: This is provided so that frontend developers have as little backend friction
#       as possible. Full stack developers can turn this feature off by setting
#       AUTO_LAUNCH_BACKEND=0 with their make command.
# $(1) is the command to run.
# -------------------------------------------------
define run_command_with_backend
	if [ $(AUTO_LAUNCH_BACKEND) -eq 1 ]; then \
		echo "[INFO] [Auto Launch Backend] Auto launching backend..."; \
		echo "[INFO] [Auto Launch Backend] Calling 'down-backend' target to ensure clean state..."; \
		$(MAKE) down-backend --no-print-directory; \
		echo "[INFO] [Auto Launch Backend] Calling 'up-backend' target..."; \
		$(MAKE) up-backend --no-print-directory; \
		$(1) || exit 1; \
	else \
		$(1); \
	fi
endef


# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_HELP
  include devops-toolkit/shared/make/help.mk
endif

ifndef INCLUDED_ANDROID_APP_CONFIGURATION
  include devops-toolkit/frontend/make/utils/android_app_configuration.mk
endif

ifndef INCLUDED_IOS_APP_CONFIGURATION
  include devops-toolkit/frontend/make/utils/ios_app_configuration.mk
endif

logs:
	mkdir -p logs

## Run flutter doctor
check:
	@flutter doctor

## Up the backend
up-backend:
	@echo "[INFO] [Up Backend] Starting backend for ENV=$(ENV)..."
	@$(MAKE) -C $(BACKEND_GATEWAY_PATH) up PRINT_INFO=0

## Down the backend
down-backend:
	@echo "[INFO] [Down Backend] Stopping backend for ENV=$(ENV)..."
	@$(MAKE) -C $(BACKEND_GATEWAY_PATH) down PRINT_INFO=0

## Clean the backend
clean-backend:
	@echo "[INFO] [Clean Backend] Cleaning backend for ENV=$(ENV)..."
	@$(MAKE) -C $(BACKEND_GATEWAY_PATH) clean PRINT_INFO=0

# Export the current backend domain based on the environment
_export_current_backend_domain:
	@echo "[INFO] [Export Backend Domain] Exporting backend domain for ENV=$(ENV)..." >&2
ifneq (,$(filter $(ENV),$(DEV_TEST_ENV)))
	# Will cause the well_known retrieval to fail silently
	@echo 'export CURRENT_BACKEND_DOMAIN="example.com"'
else ifneq (,$(filter $(ENV),$(DEV_ENV)))
	@echo 'export CURRENT_BACKEND_DOMAIN="$$($(MAKE) -C $(BACKEND_GATEWAY_PATH) print-public-app-domain --no-print-directory PRINT_INFO=0)"'
else ifneq (,$(filter $(ENV),$(STAGING_ENV)))
	# Staging not supported yet
else ifneq (,$(filter $(ENV),$(PROD_ENV)))
	@echo 'export CURRENT_BACKEND_DOMAIN="thepoofapp.com"'
endif

# Run API integration tests (non-UI logic tests)
_integration-test: AUTO_LAUNCH_BACKEND ?= 1
_integration-test: logs
	@case "$(ENV)" in \
	  $(DEV_TEST_ENV)|$(STAGING_TEST_ENV)) \
	    $(call run_command_with_backend, \
	      echo "[INFO] [Integration Test] Running API tests for ENV=$(ENV)..." && \
	      set -o pipefail && \
		  eval "$$($(MAKE) _export_current_backend_domain --no-print-directory)" && \
	      flutter test integration_test/api --dart-define=ENV=$(ENV) --dart-define=LOG_LEVEL=$(LOG_LEVEL) $(VERBOSE_FLAG) 2>&1 | tee logs/integration_test_$(PLATFORM)_$(ENV).log \
	    ); \
	    ;; \
	  *) \
	    echo "Invalid ENV: $(ENV). Choose from [$(DEV_TEST_ENV)|$(STAGING_TEST_ENV)]."; exit 1;; \
	esac

# Run API integration tests (non-UI logic tests) for iOS
integration-test-ios: _ios_app_configuration
	@$(MAKE) _integration-test --no-print-directory

# Run API integration tests (non-UI logic tests) for Android
integration-test-android: _android_app_configuration
	@$(MAKE) _integration-test --no-print-directory

# Run end-to-end (UI) tests
_e2e-test: AUTO_LAUNCH_BACKEND ?= 1
_e2e-test: logs
	@case "$(ENV)" in \
	  $(DEV_TEST_ENV)|$(STAGING_TEST_ENV)) \
	    $(call run_command_with_backend, \
	      echo "[INFO] [E2E Test] Running UI tests for ENV=$(ENV)..." && \
	      set -o pipefail && \
		  eval "$$($(MAKE) _export_current_backend_domain --no-print-directory)" && \
	      flutter test integration_test/e2e --dart-define=ENV=$(ENV) --dart-define=LOG_LEVEL=$(LOG_LEVEL) $(VERBOSE_FLAG) 2>&1 | tee logs/e2e_test_$(PLATFORM)_$(ENV).log \
	    ); \
	    ;; \
	  *) \
	    echo "Invalid ENV: $(ENV). Choose from [$(DEV_TEST_ENV)|$(STAGING_TEST_ENV)]."; exit 1;; \
	esac

# Run end-to-end (UI) tests for iOS
e2e-test-ios: _ios_app_configuration
	@$(MAKE) _e2e-test --no-print-directory PLATFORM=ios

# Run end-to-end (UI) tests for Android
e2e-test-android: _android_app_configuration
	@$(MAKE) _e2e-test --no-print-directory PLATFORM=android

# Run the app in a specific environment (ENV=dev|dev-test|staging|prod)
_run-env: logs
	@echo "[INFO] Running Flutter app for ENV=$(ENV)"
	@$(call run_command_with_backend, \
		eval "$$($(MAKE) _export_current_backend_domain --no-print-directory)" && \
		flutter run --target lib/main/main_$(ENV).dart --dart-define=ENV=$(ENV) --dart-define=LOG_LEVEL=$(LOG_LEVEL) $(VERBOSE_FLAG) 2>&1 | tee logs/run_$(PLATFORM)_$(ENV).log);

# Run the app in a specific environment (ENV=dev|dev-test|staging|prod) with respective auto backend behavior
_run: AUTO_LAUNCH_BACKEND ?= 1
_run:
	@case "$(ENV)" in \
	  $(DEV_ENV)|$(STAGING_ENV)) \
	    $(MAKE) _run-env --no-print-directory AUTO_LAUNCH_BACKEND=$(AUTO_LAUNCH_BACKEND) ENV=$(ENV); \
	    ;; \
	  $(DEV_TEST_ENV)|$(PROD_ENV)) \
	    $(MAKE) _run-env --no-print-directory AUTO_LAUNCH_BACKEND=0 ENV=$(ENV); \
	    ;; \
	  *) \
	    echo "Invalid ENV: $(ENV). Choose from [$(DEV_ENV)|$(DEV_TEST_ENV)|$(STAGING_ENV)|$(PROD_ENV)]."; exit 1;; \
	esac

## Run the app in a specific environment (ENV=dev|dev-test|staging|prod) for ios
run-ios: _ios_app_configuration
	@$(MAKE) _run --no-print-directory PLATFORM=ios

## Run the app in a specific environment (ENV=dev|dev-test|staging|prod) for android
run-android: _android_app_configuration
	@$(MAKE) _run --no-print-directory PLATFORM=android

## Build command for Android (production, release mode, appbundle for Play Store)
build-android: logs _android_app_configuration
	@if [ "$(ENV)" = "$(PROD_ENV)" ]; then \
		eval "$$($(MAKE) _export_current_backend_domain --no-print-directory)" && \
		echo "[INFO] [Build Android] Building..."; \
		flutter build appbundle --release --target lib/main/main_prod.dart $(VERBOSE_FLAG) 2>&1 | tee logs/build_android.log; \
	else \
		echo "[ERROR] [Build Android] Skipping Android build for ENV=$(ENV). Only ENV=$(PROD_ENV) is allowed."; \
		exit 1; \
	fi

## Build command for iOS (production, release mode)
build-ios: logs _ios_app_configuration
	@if [ "$(ENV)" = "$(PROD_ENV)" ]; then \
		eval "$$($(MAKE) _export_current_backend_domain --no-print-directory)" && \
		echo "[INFO] [Build iOS] Building..."; \
		flutter build ios --release --no-codesign --target lib/main/main_prod.dart $(VERBOSE_FLAG) 2>&1 | tee logs/build_ios.log; \
	else \
		echo "[ERROR] [Build iOS] Skipping iOS build for ENV=$(ENV). Only ENV=$(PROD_ENV) is allowed."; \
		exit 1; \
	fi

## Flutter clean, removes build artifacts and logs
clean:
	@flutter clean
	@rm -rf logs/*

## CI iOS pipeline: Starts backend, runs both integration and e2e tests, and then shuts down backend
ci-ios::
	@echo "[INFO] [CI] Starting pipeline..."
	@echo "[INFO] [CI] Calling 'integration-test-ios' target..."
	@$(MAKE) integration-test-ios --no-print-directory AUTO_LAUNCH_BACKEND=1
	@# $(MAKE) e2e-test-ios --no-print-directory # TODO: implement e2e tests
	@echo "[INFO] [CI] Calling 'down-backend' target..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Pipeline complete."

## CI Android pipeline: Starts backend, runs both integration and e2e tests, and then shuts down backend
ci-android::
	@echo "[INFO] [CI] Starting pipeline..."
	@echo "[INFO] [CI] Calling 'integration-test-android' target..."
	@$(MAKE) integration-test-android --no-print-directory AUTO_LAUNCH_BACKEND=1
	@# $(MAKE) e2e-test-android --no-print-directory # TODO: implement e2e tests
	@echo "[INFO] [CI] Calling 'down-backend' target..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Pipeline complete."

help::
	@echo "--------------------------------------------------"
	@echo "[INFO] Flutter App Configuration:"
	@echo "--------------------------------------------------"
	@echo "ENV: $(ENV)"
	@echo "VERBOSE: $(VERBOSE)"
	@echo "BACKEND_GATEWAY_PATH: $(BACKEND_GATEWAY_PATH)"
	@echo

