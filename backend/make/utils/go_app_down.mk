# ----------------------
# Go App Down Target
# ----------------------

SHELL := /bin/bash

.PHONY: down

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_DOWN := 1


ifndef INCLUDED_GO_APP_DEPS
  include devops-toolkit/backend/make/utils/go_app_deps.mk
endif


## Shuts down all containers (WITH_DEPS=1 to 'down' dependency services as well)
down: _deps-down
	@echo "[INFO] [Down] Removing containers & volumes, keeping images..."
	$(COMPOSE_CMD) $(COMPOSE_PROFILE_FLAGS) down -v --remove-orphans

	@echo "[INFO] [Down] Removing network '$(COMPOSE_NETWORK_NAME)'..."
	@docker network rm $(COMPOSE_NETWORK_NAME) && echo "[INFO] [Down] Network '$(COMPOSE_NETWORK_NAME)' successfully removed." || \
		echo "[WARN] [Down] 'network rm $(COMPOSE_NETWORK_NAME)' failed (network most likely already removed or still being used) Ignoring..."

	@echo "[INFO] [Down] Done."

