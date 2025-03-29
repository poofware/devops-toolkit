# ----------------------
# Go App Clean Target
# ----------------------

SHELL := /bin/bash

.PHONY: clean

# Check that the current working directory is the root of a Go app by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go app.)
endif

INCLUDED_GO_APP_CLEAN := 1


ifndef INCLUDED_GO_APP_DOWN
  include devops-toolkit/backend/make/go-app/go_app_down.mk
endif


## Cleans everything (containers, images, volumes) (WITH_DEPS=1 to 'clean' dependency services as well)
clean: _deps-clean
	@echo "[INFO] [Clean] Running down target..."
	@$(MAKE) down --no-print-directory WITH_DEPS=0
	@echo "[INFO] [Clean] Full nuke of containers, images, volumes, networks..."
	$(COMPOSE_CMD) $(COMPOSE_PROFILE_FLAGS_DOWN_BUILD) down --rmi local -v --remove-orphans
	@echo "[INFO] [Clean] Done."
