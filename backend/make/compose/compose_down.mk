# ----------------------
# Compose Down Target
# ----------------------

SHELL := /bin/bash

.PHONY: down

# Check that the current working directory is the root of a project by verifying that the root Makefile exists.
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

INCLUDED_COMPOSE_DOWN := 1


ifndef INCLUDED_COMPOSE_DEPS
  include devops-toolkit/backend/make/compose/compose_deps.mk
endif


_down-network:
	@echo "[INFO] [Down] Removing network '$(COMPOSE_NETWORK_NAME)'..."
	@docker network rm $(COMPOSE_NETWORK_NAME) && echo "[INFO] [Down] Network '$(COMPOSE_NETWORK_NAME)' successfully removed." || \
		echo "[WARN] [Down] 'network rm $(COMPOSE_NETWORK_NAME)' failed (network most likely already removed or still being used) Ignoring..."


## Shuts down all containers (WITH_DEPS=1 to 'down' dependency projects as well)
down:: _deps-down
	@echo "[INFO] [Down] Removing containers & volumes, keeping images..."
	@$(COMPOSE_CMD) $(COMPOSE_DOWN_PROFILE_FLAGS) down -v --remove-orphans

	@$(MAKE) _down-network --no-print-directory

	@echo "[INFO] [Down] Done."

