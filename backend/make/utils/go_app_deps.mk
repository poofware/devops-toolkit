# --------------------
# Go App Deps Target
# --------------------

SHELL := /bin/bash

.PHONY: _deps-%

# Check that the current working directory is the root of a Go service by verifying that go.mod exists.
ifeq ($(wildcard go.mod),)
  $(error Error: go.mod not found. Please ensure you are in the root directory of your Go service.)
endif

INCLUDED_GO_APP_DEPS := 1


# Do not do existence checks, the target that uses this will do the check
ifndef DEPS
  $(error DEPS is not set. Please define it in your local Makefile or environment. Define it empty if not needed. \
    Example: DEPS="/path/to/auth-service /path/to/account-service" or DEPS="")
endif

ifndef WITH_DEPS
  $(error WITH_DEPS is not set. Please define it in your local Makefile or environment. \
	Example: WITH_DEPS=1)
endif


_deps-%:
	@if [ "$(WITH_DEPS)" -eq 1 ] && [ -n "$(DEPS)" ]; then \
		for dep in $(DEPS); do \
			dep_path=$${dep##*:}; \
			if [ ! -d "$$dep_path" ]; then \
				echo "[ERROR] [Deps-$*] Dependency '$$dep_path' found in DEPS does not exist."; \
				exit 1; \
			fi; \
			echo "[INFO] [Deps-$*] Running 'make $* WITH_DEPS=1' in $$dep_path..."; \
			env -i \
				WITH_DEPS=1 \
				HCP_TOKEN_ENC_KEY="$(HCP_TOKEN_ENC_KEY)" \
				HCP_ENCRYPTED_API_TOKEN="$(HCP_ENCRYPTED_API_TOKEN)" \
				ENV="$(ENV)" \
				$(MAKE) -C $$dep_path $* || exit $$?; \
		done; \
	fi
