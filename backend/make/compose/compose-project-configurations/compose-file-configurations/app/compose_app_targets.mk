# ------------------------------
# Compose App Targets
# ------------------------------

SHELL := /bin/bash


# Check that the current working directory is the root of a project by verifying that the root Makefile exists.
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif

ifndef INCLUDED_COMPOSE_APP_CONFIGURATION
  $(error [ERROR] [Compose App Configuration] The Compose App Configuration must be included before any Compose App Targets.)
endif

ifdef INCLUDED_COMPOSE_DEPS_TARGETS
  $(error [ERROR] [Compose App Configuration] The Compose Deps Targets must not be included before this file. \
	This file controls the inclusion of the deps targets strategically.)
endif

ifdef INCLUDED_COMPOSE_PROJECT_TARGETS
  $(error [ERROR] [Compose App Configuration] The Compose Project Targets must not be included before this file.)
endif


# --------------------------------
# Targets
# --------------------------------

_export-target-platform:
	$(eval export TARGET_PLATFORM := $(shell docker info --format '{{.OSType}}/{{.Architecture}}'))

build:: _export-target-platform
up:: _export-target-platform
integration-test:: _export-target-platform
up-app-post-check:: _export-target-platform
help:: _export-target-platform
migrate:: _export-target-platform
down:: _export-target-platform
clean:: _export-target-platform
ci:: _export-target-platform

ifneq (,$(filter $(ENV),$(DEV_TEST_ENV) $(DEV_ENV)))

  ifneq ($(APP_IS_GATEWAY),1)
    # If the app is not a gateway to its dependencies, we need to include the deps targets prior to the app targets.
    # This ensures that the app targets are run after the deps are built/up, ensuring no interference with the deps and vice versa.
    # Specifically, APP_HOST_PORT compute
    include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose-deps-targets/compose_deps_targets.mk
  endif

  # For Dev environment: Resolve backend URL if dependencies are present
  ifdef BACKEND_GATEWAY_PATH
    ifndef INCLUDED_BACKEND_DOMAIN_UTILS
      include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/utils/backend_domain_utils.mk
    endif

    _export_backend_url_dev:
    ifdef NEXTJS_BACKEND_ENV_VAR
	    @echo "[INFO] [$(APP_NAME)] Resolving backend URL from $(BACKEND_GATEWAY_PATH)..."
	    $(eval RAW_URL := $(shell $(_backend_domain_cmd)))
	    $(eval FULL_URL := $(if $(findstring http,$(RAW_URL)),$(RAW_URL),https://$(RAW_URL)))
	    $(eval export $(NEXTJS_BACKEND_ENV_VAR) := $(FULL_URL))
	    @echo "[INFO] [$(APP_NAME)] Backend URL: $(NEXTJS_BACKEND_ENV_VAR)=$(FULL_URL)"
    endif

    up:: _export_backend_url_dev
  endif

  ifeq ($(ENABLE_NGROK_FOR_DEV),1)
    _export_ngrok_url_as_app_url:
    ifndef APP_URL_FROM_ANYWHERE
		$(eval NGROK_HOST_PORT := $(shell $(COMPOSE_CMD) port ngrok $(NGROK_PORT) | cut -d ':' -f 2))
		$(eval export APP_URL_FROM_ANYWHERE := $(shell $(DEVOPS_TOOLKIT_PATH)/backend/scripts/get_ngrok_url.sh $(NGROK_HOST_PORT)))
		@echo "[INFO] [$(APP_NAME)] Ngrok URL: $(APP_URL_FROM_ANYWHERE)" >&2
    endif

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
  endif

  _export_app_host_port:
  ifndef APP_HOST_PORT
	  $(eval export APP_HOST_PORT := $(shell \
	    $(COMPOSE_CMD) port $(COMPOSE_PROFILE_APP_SERVICES) $(APP_PORT) 2>/dev/null \
	    | cut -d ':' -f2 | grep -E '^[0-9]+$$' || \
	    $(DEVOPS_TOOLKIT_PATH)/backend/scripts/find_available_port.sh 8080 \
	  ))
  endif

  build:: _export_app_host_port
  up:: _export_app_host_port

  ifneq ($(ENABLE_NGROK_FOR_DEV),1)
    _export_lan_url_as_app_url:
    ifndef APP_URL_FROM_ANYWHERE
		$(eval export APP_URL_FROM_ANYWHERE = http://$(shell $(DEVOPS_TOOLKIT_PATH)/backend/scripts/get_lan_ip.sh):$(APP_HOST_PORT))
		@echo "[INFO] [$(APP_NAME)] LAN URL: $(APP_URL_FROM_ANYWHERE)" >&2
    endif

    build:: _export_lan_url_as_app_url
    up:: _export_lan_url_as_app_url
    print-public-app-domain:: _export_app_host_port _export_lan_url_as_app_url
  endif

  # If the app is a gateway to apps that are in deps, we need to include the deps targets after the app targets.
  # This ensures that gateway app targets run first, causing the dependency apps to reuse the same exported network configurations.

else

  DEPLOY_TARGET_FOR_ENV := fly

  ifneq (,$(filter $(ENV),$(STAGING_ENV) $(STAGING_TEST_ENV)))
    DEPLOY_TARGET_FOR_ENV := $(STAGING_DEPLOY_TARGET)
  else ifneq (,$(filter $(ENV),$(PROD_ENV)))
    DEPLOY_TARGET_FOR_ENV := $(PROD_DEPLOY_TARGET)
  endif

  ifeq ($(DEPLOY_TARGET_FOR_ENV),fly)

  # SKIP_FLY_WIREGUARD: Set to 1 for standalone services that don't need internal networking
  # (e.g., stateless APIs without database connections)
  SKIP_FLY_WIREGUARD ?= 0
  
  _export_fly_api_token:
  ifndef FLY_API_TOKEN
    ifdef BWS_ACCESS_TOKEN
	  $(eval export BWS_PROJECT_NAME := shared-$(ENV))
	  $(eval export FLY_API_TOKEN := $(shell $(DEVOPS_TOOLKIT_PATH)/shared/scripts/fetch_bws_secret.sh FLY_API_TOKEN | jq -r '.FLY_API_TOKEN // empty'))
	  $(if $(FLY_API_TOKEN),@echo "[INFO] [Export Fly Api Token] Fly API token fetched from BWS.",)
    endif
	  $(if $(FLY_API_TOKEN),,$(error FLY_API_TOKEN is required for Fly.io deploys. Export FLY_API_TOKEN in your environment or set BWS_ACCESS_TOKEN to fetch from Bitwarden Secrets.))
  endif

  ifeq ($(SKIP_FLY_WIREGUARD),0)
  ## Wireguard up target (for services needing internal networking)
  fly_wireguard_up:
  ifndef FLY_WIREGUARD_UP
	  $(eval export FLY_WIREGUARD_UP := 1)
	  @export LOG_LEVEL=; \
	  echo "[INFO] [Fly Wireguard Up] Calling Fly Wireguard Down target to ensure clean state..."; \
	  env -u MAKELEVEL $(MAKE) fly_wireguard_down --no-print-directory; \
	  echo "[INFO] [Fly Wireguard Up] Creating WireGuard peer $(FLY_WIREGUARD_PEER_NAME) in region $(FLY_WIREGUARD_PEER_REGION) (with auto-retry)…"; \
	  set -e ; \
	  if fly wireguard create $(FLY_ORG_NAME) \
	  	$(FLY_WIREGUARD_PEER_REGION) \
	  	$(FLY_WIREGUARD_PEER_NAME) \
	  	$(FLY_WIREGUARD_CONF_FILE); then \
		  echo "[INFO] [Fly Wireguard Up] Peer created on first attempt." ; \
	  else \
		  echo "[WARN] [Fly Wireguard Up] Peer creation failed – duplicate or peer-limit. Selecting a peer to delete…" ; \
		  PEERS_JSON=$$(fly wireguard list $(FLY_ORG_NAME) --json) ; \
		  TARGET_PEER=$$(echo "$$PEERS_JSON" \
			| jq -r --arg name "$(FLY_WIREGUARD_PEER_NAME)" 'map(select(.Name==$$name))[0].Name // empty') ; \
		  if [ -z "$$TARGET_PEER" ] ; then \
			  TARGET_PEER=$$(echo "$$PEERS_JSON" | jq -r '.[-1].Name // empty') ; \
		  fi ; \
		  if [ -n "$$TARGET_PEER" ] ; then \
			  echo "[INFO] [Fly Wireguard Up] Removing peer '$$TARGET_PEER'…"; \
			  fly wireguard remove $(FLY_ORG_NAME) $$TARGET_PEER || true ; \
		  else \
			  echo "[ERROR] [Fly Wireguard Up] No peers found to delete; aborting." ; \
			  exit 1 ; \
		  fi ; \
		  fly wireguard create $(FLY_ORG_NAME) \
			$(FLY_WIREGUARD_PEER_REGION) \
			$(FLY_WIREGUARD_PEER_NAME) \
			$(FLY_WIREGUARD_CONF_FILE) ; \
	  fi

	  @echo "[INFO] [Fly Wireguard Up] Starting WireGuard interface…"
	  @sudo wg-quick up $(FLY_WIREGUARD_CONF_FILE)
	  @echo "[INFO] [Fly Wireguard Up] Done – tunnel is live."
  endif

  ## Wireguard down target
  fly_wireguard_down:
	  @if [ "$(MAKELEVEL)" -eq 0 ]; then \
		  export LOG_LEVEL=; \
		  echo "[INFO] [Fly Wireguard Down] Stopping wireguard connection to fly.io..."; \
		  sudo wg-quick down $(FLY_WIREGUARD_CONF_FILE) || echo "[WARN] [Fly Wireguard Down] Ignoring...no wireguard connection to fly.io found."; \
		  rm -f $(FLY_WIREGUARD_CONF_FILE); \
		  fly wireguard list $(FLY_ORG_NAME) | grep -q "\b$(FLY_WIREGUARD_PEER_NAME)\b" && \
			fly wireguard remove $(FLY_ORG_NAME) $(FLY_WIREGUARD_PEER_NAME) || true; \
		  echo "[INFO] [Fly Wireguard Down] Done. Wireguard connection to fly.io is down."; \
	  fi

  integration-test:: _export_fly_api_token fly_wireguard_up
  up:: _export_fly_api_token fly_wireguard_up
  ci:: _export_fly_api_token fly_wireguard_up
  clean:: _export_fly_api_token fly_wireguard_up
  down:: _export_fly_api_token fly_wireguard_up _up-network
	  @export LOG_LEVEL=; \
	  if [ "$(EXCLUDE_COMPOSE_PROFILE_APP)" -eq 1 ]; then \
		  echo "[INFO] [Down] Skipping fly app destruction... EXCLUDE_COMPOSE_PROFILE_APP is set to 1"; \
	  else \
		  echo "[INFO] [Down] Destroying app $(FLY_APP_NAME) on fly.io..."; \
		  fly app destroy $(FLY_APP_NAME) --yes; \
		  echo "[INFO] [Down] Done. App $(FLY_APP_NAME) destroyed."; \
	  fi; \
	  if [ -n "$(COMPOSE_PROFILE_MIGRATE_SERVICES)" ]; then \
		  echo "[INFO] [Down] Wiping the migrated isolated schema from the database..."; \
		  $(MAKE) migrate --no-print-directory MIGRATE_MODE=backward COMPOSE_PROFILE_MIGRATE_SERVICES="$(COMPOSE_PROFILE_MIGRATE_SERVICES)"; \
		  echo "[INFO] [Down] Done. Isolated schema wiped from the database."; \
	  fi
  migrate:: _export_fly_api_token fly_wireguard_up

  ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
    include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose_project_targets.mk
  endif
  
  integration-test:: fly_wireguard_down
  up:: fly_wireguard_down
  ci:: fly_wireguard_down
  clean:: fly_wireguard_down
  down:: fly_wireguard_down
  migrate:: fly_wireguard_down

  else
  # SKIP_FLY_WIREGUARD=1: No WireGuard needed, just token export
  integration-test:: _export_fly_api_token
  up:: _export_fly_api_token
  ci:: _export_fly_api_token
  clean:: _export_fly_api_token
  down:: _export_fly_api_token
	  @export LOG_LEVEL=; \
	  if [ "$(EXCLUDE_COMPOSE_PROFILE_APP)" -eq 1 ]; then \
		  echo "[INFO] [Down] Skipping fly app destruction... EXCLUDE_COMPOSE_PROFILE_APP is set to 1"; \
	  else \
		  echo "[INFO] [Down] Destroying app $(FLY_APP_NAME) on fly.io..."; \
		  fly app destroy $(FLY_APP_NAME) --yes; \
		  echo "[INFO] [Down] Done. App $(FLY_APP_NAME) destroyed."; \
	  fi
  migrate:: _export_fly_api_token

  ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
    include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose_project_targets.mk
  endif
  endif

  # OVERRIDE default _up-app target to use fly.io instead of docker-compose
  _up-app:
	  @export LOG_LEVEL=; \
	  if fly app list -q | grep -q "\b$(FLY_APP_NAME)\b"; then \
		  echo "[INFO] [Up App] App $(FLY_APP_NAME) already exists."; \
	  else \
	  	  echo "[INFO] [Up App] Creating app $(FLY_APP_NAME) on fly.io..."; \
	  	  fly apps create $(FLY_APP_NAME) --org $(FLY_ORG_NAME); \
	  	  echo "[INFO] [Up App] Done. App $(FLY_APP_NAME) created."; \
	  fi; \
	  \
	  if ! fly secrets list --app $(FLY_APP_NAME) --json \
	  	| jq -e '.[].Name | select(.=="BWS_ACCESS_TOKEN")' >/dev/null; \
	  then \
		  echo "[INFO] [Up App] Secret BWS_ACCESS_TOKEN not found – setting it…"; \
		  fly secrets set BWS_ACCESS_TOKEN=$(BWS_ACCESS_TOKEN) --app $(FLY_APP_NAME) --stage; \
		  echo "[INFO] [Up App] Secret BWS_ACCESS_TOKEN staged (will deploy with next fly deploy)."; \
	  else \
		  echo "[INFO] [Up App] Secret BWS_ACCESS_TOKEN already present – skipping."; \
	  fi; \
	  \
	  echo "[INFO] [Up App] Starting app $(FLY_APP_NAME) on fly.io..."; \
	  fly deploy -a $(FLY_APP_NAME) -c $(FLY_TOML_PATH) --image $(APP_NAME) --local-only --ha=false --yes; \
	  echo "[INFO] [Up App] Done. App $(FLY_APP_NAME) started."

  else ifeq ($(DEPLOY_TARGET_FOR_ENV),vercel)

# Include backend domain utils if BACKEND_GATEWAY_PATH is set (for resolving backend URL)
ifdef BACKEND_GATEWAY_PATH
  ifndef INCLUDED_BACKEND_DOMAIN_UTILS
    include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/utils/backend_domain_utils.mk
  endif
endif

_export_vercel_token:
ifndef VERCEL_TOKEN
	$(error [Export Vercel Token] VERCEL_TOKEN is required for Vercel deploys. Export VERCEL_TOKEN in your environment or via your secret manager.)
endif

_export_vercel_project_vars:
ifndef VERCEL_ORG_ID
	@echo "[INFO] [Export Vercel Project Vars] VERCEL_ORG_ID not set; relying on .vercel/project.json if present."
endif
ifndef VERCEL_PROJECT_ID
	@echo "[INFO] [Export Vercel Project Vars] VERCEL_PROJECT_ID not set; relying on .vercel/project.json if present."
endif

_assert_vercel_project:
	@if [ ! -f ".vercel/project.json" ]; then \
		if [ -z "$(strip $(VERCEL_ORG_ID))" ] || [ -z "$(strip $(VERCEL_PROJECT_ID))" ]; then \
			echo "[ERROR] [Vercel Project] VERCEL_ORG_ID and VERCEL_PROJECT_ID must be set when .vercel/project.json is absent."; \
			exit 1; \
		fi; \
	fi

integration-test:: _export_vercel_token _export_vercel_project_vars
up:: _export_vercel_token _export_vercel_project_vars _assert_vercel_project
ci:: _export_vercel_token _export_vercel_project_vars _assert_vercel_project
clean:: _export_vercel_token _export_vercel_project_vars
down:: _export_vercel_token _export_vercel_project_vars
migrate:: _export_vercel_token _export_vercel_project_vars

  ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
    include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose_project_targets.mk
  endif

# Override _up entirely - Vercel builds remotely, no compose needed
_up:
	@echo "[INFO] [Up] Deploying to Vercel (skipping compose build/network/migrate)..."
	@$(MAKE) _up-app --no-print-directory

# Override _up-app to deploy via Vercel CLI
# Note: If NEXTJS_BACKEND_ENV_VAR is set (e.g., NEXT_PUBLIC_GENERATOR_URL),
# the backend URL is resolved via _backend_domain_cmd (health check visible on stderr)
_up-app:
	@set -euo pipefail; \
	export LOG_LEVEL=; \
	if ! command -v vercel >/dev/null 2>&1; then \
		echo "[ERROR] [Up App] vercel CLI not found. Install with 'npm i -g vercel'."; \
		exit 1; \
	fi; \
	if [ -z "$(strip $(VERCEL_TOKEN))" ]; then \
		echo "[ERROR] [Up App] VERCEL_TOKEN is required but not set."; \
		exit 1; \
	fi; \
	BUILD_ENV_FLAGS=""; \
	if [ -n "$(NEXTJS_BACKEND_ENV_VAR)" ] && [ -n "$(BACKEND_GATEWAY_PATH)" ]; then \
		echo "[INFO] [Up App] Resolving backend URL (with health check)..."; \
		BACKEND_DOMAIN="$$( $(_backend_domain_cmd) )"; rc=$$?; \
		[ $$rc -eq 0 ] || exit $$rc; \
		if [ -n "$$BACKEND_DOMAIN" ]; then \
			export $(NEXTJS_BACKEND_ENV_VAR)="https://$$BACKEND_DOMAIN"; \
			BUILD_ENV_FLAGS="--build-env $(NEXTJS_BACKEND_ENV_VAR)=https://$$BACKEND_DOMAIN"; \
			echo "[INFO] [Up App] $(NEXTJS_BACKEND_ENV_VAR)=https://$$BACKEND_DOMAIN"; \
		else \
			echo "[WARN] [Up App] Could not resolve backend URL, deploying without it"; \
		fi; \
	fi; \
	echo "[INFO] [Up App] Deploying $(APP_NAME) to Vercel (remote build)..."; \
	DEPLOY_URL=$$(VERCEL_ORG_ID=$(VERCEL_ORG_ID) VERCEL_PROJECT_ID=$(VERCEL_PROJECT_ID) VERCEL_PROJECT_NAME=$(VERCEL_PROJECT_NAME) \
		vercel deploy --prod --token $(VERCEL_TOKEN) --yes --force --cwd $(CURDIR) $$BUILD_ENV_FLAGS \
		| /usr/bin/grep -Eo 'https://[^ ]+' | tail -n1); \
	if [ -z "$$DEPLOY_URL" ]; then \
		echo "[ERROR] [Up App] Failed to capture Vercel deploy URL."; \
		exit 1; \
	fi; \
	echo "$$DEPLOY_URL" > .last_vercel_deploy_url; \
	echo "[INFO] [Up App] Done. App $(APP_NAME) available at $$DEPLOY_URL."

## Override down to avoid destructive remote removal (manage from Vercel)
down::
	@echo "[INFO] [Down] Vercel deploy target selected – skipping remote teardown. Manage removal from the Vercel dashboard if needed."

  else ifeq ($(DEPLOY_TARGET_FOR_ENV),shuttle)

_export_shuttle_api_key:
ifndef SHUTTLE_API_KEY
	@echo "[WARN] [Export Shuttle API Key] SHUTTLE_API_KEY not set; using cargo shuttle login credentials if available."
endif

_assert_shuttle_project:
	@if [ ! -f "Shuttle.toml" ]; then \
		echo "[ERROR] [Shuttle Project] Shuttle.toml not found in project root."; \
		exit 1; \
	fi

integration-test:: _export_shuttle_api_key
up:: _export_shuttle_api_key _assert_shuttle_project
ci:: _export_shuttle_api_key _assert_shuttle_project
clean:: _export_shuttle_api_key
down:: _export_shuttle_api_key

  ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
    include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose_project_targets.mk
  endif

# Override _up entirely - Shuttle builds Rust directly, no compose needed
_up:
	@echo "[INFO] [Up] Deploying to Shuttle (skipping compose build/network/migrate)..."
	@$(MAKE) _up-app --no-print-directory

# Override _up-app to deploy via Shuttle CLI
_up-app:
	@set -euo pipefail; \
	export LOG_LEVEL=; \
	if ! command -v cargo-shuttle >/dev/null 2>&1; then \
		echo "[ERROR] [Up App] cargo-shuttle CLI not found. Install with 'cargo install cargo-shuttle'."; \
		exit 1; \
	fi; \
	echo "[INFO] [Up App] Deploying $(APP_NAME) to Shuttle..."; \
	cargo shuttle deploy --name $(SHUTTLE_PROJECT_NAME) --allow-dirty; \
	DEPLOY_URL=$$(cargo shuttle project status --name $(SHUTTLE_PROJECT_NAME) 2>/dev/null | /usr/bin/grep -oE 'https://[a-zA-Z0-9_-]+\.shuttle\.app' | head -1); \
	if [ -n "$$DEPLOY_URL" ]; then \
		echo "[INFO] [Up App] Done. App $(APP_NAME) available at $$DEPLOY_URL"; \
	else \
		echo "[INFO] [Up App] Done. App $(APP_NAME) deployed to Shuttle."; \
	fi

## Override down to avoid destructive remote removal (manage from Shuttle)
down::
	@echo "[INFO] [Down] Shuttle deploy target selected – skipping remote teardown. Manage removal from the Shuttle dashboard if needed."

CUSTOM_PRINT_PUBLIC_APP_DOMAIN := 1

## Override print-public-app-domain to get URL from Shuttle project status
print-public-app-domain::
	@DEPLOY_URL=$$(cargo shuttle project status --name $(SHUTTLE_PROJECT_NAME) 2>/dev/null | /usr/bin/grep -oE 'https://[a-zA-Z0-9_-]+\.shuttle\.app' | head -1); \
	if [ -n "$$DEPLOY_URL" ]; then \
		echo "$$DEPLOY_URL" | sed -e 's~^https://~~'; \
	else \
		echo "[ERROR] [Print Public App Domain] Could not determine Shuttle URL. Deploy first or check 'cargo shuttle project status'." >&2; \
		exit 1; \
	fi

  endif

endif

## Prints the domain that you can use to access the app from anywhere with https
## (Only define default if not already defined by deploy target like Shuttle)
ifndef CUSTOM_PRINT_PUBLIC_APP_DOMAIN
print-public-app-domain::
	@$(DEVOPS_TOOLKIT_PATH)/backend/scripts/health_check.sh
	@echo $$APP_URL_FROM_ANYWHERE | sed -e 's~^https://~~'
endif

# Include compose project targets for dev environments (if not already included)
ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose_project_targets.mk
endif


INCLUDED_COMPOSE_APP_TARGETS := 1
