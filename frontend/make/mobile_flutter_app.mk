# --------------------------------
# Mobile Flutter App
# --------------------------------

SHELL := /bin/bash

.PHONY: run-ios run-android \
	build-ios build-android \
	e2e-test-ios e2e-test-android \
	integration-test-ios integration-test-android \
	ci-ios ci-android

# --------------------------------
# Internal Variable Declaration
# --------------------------------

ifndef INCLUDED_FLUTTER_APP_CONFIGURATION
  include devops-toolkit/frontend/make/utils/flutter_app_configuration.mk
endif

# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_FLUTTER_APP_TARGETS
  include devops-toolkit/frontend/make/utils/flutter_app_targets.mk
endif

ifndef INCLUDED_ANDROID_APP_CONFIGURATION_TARGETS
  include devops-toolkit/frontend/make/utils/android_app_configuration_targets.mk
endif

ifndef INCLUDED_IOS_APP_CONFIGURATION_TARGETS
  include devops-toolkit/frontend/make/utils/ios_app_configuration_targets.mk
endif

# Run API integration tests (non-UI logic tests) for iOS
integration-test-ios: _ios_app_configuration
	@$(MAKE) _integration-test --no-print-directory PLATFORM=ios

# Run API integration tests (non-UI logic tests) for Android
integration-test-android: _android_app_configuration
	@$(MAKE) _integration-test --no-print-directory PLATFORM=android

# Run end-to-end (UI) tests for iOS
e2e-test-ios: _ios_app_configuration
	@$(MAKE) _e2e-test --no-print-directory PLATFORM=ios

# Run end-to-end (UI) tests for Android
e2e-test-android: _android_app_configuration
	@$(MAKE) _e2e-test --no-print-directory PLATFORM=android

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

## CI iOS pipeline: Starts backend, runs both integration and e2e tests, and then shuts down backend
ci-ios::
	@echo "[INFO] [CI] Starting pipeline..."
	@echo "[INFO] [CI] Calling 'down-backend' target to ensure clean state..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Calling 'integration-test-ios' target..."
	@$(MAKE) integration-test-ios --no-print-directory AUTO_LAUNCH_BACKEND=1
	@# $(MAKE) e2e-test-ios --no-print-directory # TODO: implement e2e tests
	@echo "[INFO] [CI] Calling 'down-backend' target..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Pipeline complete."

## CI Android pipeline: Starts backend, runs both integration and e2e tests, and then shuts down backend
ci-android::
	@echo "[INFO] [CI] Starting pipeline..."
	@echo "[INFO] [CI] Calling 'down-backend' target to ensure clean state..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Calling 'integration-test-android' target..."
	@$(MAKE) integration-test-android --no-print-directory AUTO_LAUNCH_BACKEND=1
	@# $(MAKE) e2e-test-android --no-print-directory # TODO: implement e2e tests
	@echo "[INFO] [CI] Calling 'down-backend' target..."
	@$(MAKE) down-backend --no-print-directory
	@echo "[INFO] [CI] Pipeline complete."


INCLUDED_MOBILE_FLUTTER_APP := 1
