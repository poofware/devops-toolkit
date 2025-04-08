# ------------------------------
# Compose App Targets
# ------------------------------

SHELL := /bin/bash

.PHONY: help build

INCLUDED_COMPOSE_APP_TARGETS := 1

# Check that the current working directory is the root of a project by verifying that the root Makefile exists.
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

ifndef INCLUDED_COMPOSE_APP_CONFIGURATION
  $(error [ERROR] [Compose App Configuration] The Compose App Configuration must be included before any Compose App Targets.)
endif

ifdef INCLUDED_COMPOSE_PROJECT_TARGETS
  $(error [ERROR] [Compose App Configuration] The Compose Project Targets must not be included before this file.)
endif


# --------------------------------
# Targets
# --------------------------------


ifneq (,$(filter $(ENV),$(DEV_TEST_ENV) $(DEV_ENV)))

  ifeq ($(ENABLE_NGROK_FOR_DEV),1)

    _export_ngrok_url_as_app_url:
    ifndef APP_URL_FROM_ANYWHERE
		@echo "[INFO] [Export Ngrok URL] Exporting ngrok URL as App Url From Anywhere..."
		$(eval NGROK_HOST_PORT := $(shell $(COMPOSE_CMD) port ngrok $(NGROK_PORT) | cut -d ':' -f 2))
		$(eval export APP_URL_FROM_ANYWHERE := $(shell devops-toolkit/backend/scripts/get_ngrok_url.sh $(NGROK_HOST_PORT)))
		@echo "[INFO] [Export Ngrok URL] Done. App Url From Anywhere is set to: $(APP_URL_FROM_ANYWHERE)"
    endif

    # Override the COMPOSE_FILE variable to only include the ngrok compose file.
    _up-ngrok: 
    # Only need to start ngrok once, but the target may be invoked multiple times.
    ifndef NGROK_UP
		$(eval export NGROK_UP := 1)
		@$(MAKE) _up-network --no-print-directory
		@echo "[INFO] [Up Ngrok] Starting 'ngrok' service..."
		@$(COMPOSE_CMD) up -d ngrok || exit 1
    endif
  
    build:: _up-ngrok _export_ngrok_url_as_app_url

    up:: _up-ngrok _export_ngrok_url_as_app_url
  
    print-public-app-domain:: _export_ngrok_url_as_app_url

  else

    _export_lan_url_as_app_url:
    ifndef APP_URL_FROM_ANYWHERE
		@echo "[INFO] [Export LAN URL] Exporting LAN URL as App Url From Anywhere..."
		$(eval APP_HOST_PORT := $(shell \
		  $(COMPOSE_CMD) port $(COMPOSE_PROFILE_APP_SERVICES) $(APP_PORT) 2>/dev/null \
		  | cut -d ':' -f2 | grep -E '^[0-9]+$$' || \
		  devops-toolkit/backend/scripts/find_available_port.sh 8080 \
		))
		$(eval export APP_URL_FROM_ANYWHERE = http://$(shell devops-toolkit/backend/scripts/get_lan_ip.sh):$(APP_HOST_PORT))
		@echo "[INFO] [Export LAN URL] Done. App Url From Anywhere is set to: $$APP_URL_FROM_ANYWHERE"
    endif

    build:: _export_lan_url_as_app_url

    up:: _export_lan_url_as_app_url

    print-public-app-domain:: _export_lan_url_as_app_url

  endif
else
	# Staging and prod not supported at this time.
endif

## Prints the domain that you can use to access the app from anywhere with https
print-public-app-domain::
	@echo $$APP_URL_FROM_ANYWHERE | sed -e 's~^https://~~'

ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
  include devops-toolkit/backend/make/compose/compose_project_targets.mk
endif
