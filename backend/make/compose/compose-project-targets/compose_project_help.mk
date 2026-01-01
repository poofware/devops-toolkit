# ------------------------------
# Compose Project Help Target
# ------------------------------

SHELL := bash

# Check that the current working directory is the root of a project by verifying that the Makefile exists. 
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef INCLUDED_HELP
  include $(DEVOPS_TOOLKIT_PATH)/shared/make/help.mk
endif

help::
	@echo "--------------------------------------------------"
	@echo "[INFO] Compose Project Configuration variables:"
	@echo "--------------------------------------------------"
	@echo "COMPOSE_NETWORK_NAME: $(COMPOSE_NETWORK_NAME)"
	@echo "ENV: $(ENV)"
	@echo "UNIQUE_RUN_NUMBER: $(UNIQUE_RUN_NUMBER)"
	@echo "UNIQUE_RUNNER_ID: $(UNIQUE_RUNNER_ID)"
	@echo "WITH_DEPS: $(WITH_DEPS)"
	@echo "DEPS: $(DEPS)"
	@echo "COMPOSE_FILE: $(COMPOSE_FILE)"
	@echo "BWS_ACCESS_TOKEN": xxxxxxxx
	@echo "--------------------------------------------------"
	@echo
	@echo "--------------------------------------------------"
	@echo "[INFO] Effective compose services for each profile:"
	@echo "--------------------------------------------------"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_APP)" "$(strip $(COMPOSE_PROFILE_APP_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_DB)" "$(strip $(COMPOSE_PROFILE_DB_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_MIGRATE)" "$(strip $(COMPOSE_PROFILE_MIGRATE_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_BUILD_PRE_SYNC)" "$(strip $(COMPOSE_PROFILE_BUILD_PRE_SYNC_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_APP_PRE)" "$(strip $(COMPOSE_PROFILE_APP_PRE_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_APP_POST_CHECK)" "$(strip $(COMPOSE_PROFILE_APP_POST_CHECK_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_APP_INTEGRATION_TEST)" "$(strip $(COMPOSE_PROFILE_APP_INTEGRATION_TEST_SERVICES))"
	@printf "%-22s : %s\n" "$(COMPOSE_PROFILE_APP_UNIT_TEST)" "$(strip $(COMPOSE_PROFILE_APP_UNIT_TEST_SERVICES))"
	@echo "--------------------------------------------------"
	@echo "[INFO] For information on available profiles, reference $(DEVOPS_TOOLKIT_PATH)/README.md"
	@echo



INCLUDED_COMPOSE_PROJECT_HELP := 1
