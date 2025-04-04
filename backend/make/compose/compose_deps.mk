# --------------------
# Compose Deps Target
# --------------------

SHELL := /bin/bash

.PHONY: _deps-%

# Check that the current working directory is the root of a project by verifying that the root Makefile exists.  
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

INCLUDED_COMPOSE_DEPS := 1


# Do not do existence checks, the target that uses this will do the check
ifndef DEPS
  $(error DEPS is not set. Please define it in your local Makefile or environment. Define it empty if not needed. \
    Example: DEPS="/path/to/auth-service /path/to/account-service" or DEPS="")
endif

ifndef WITH_DEPS
  $(error WITH_DEPS is not set. Please define it in your local Makefile or environment. \
	Example: WITH_DEPS=1)
endif

ifndef DEPS_VAR_PASSTHROUGH
  $(error DEPS_VAR_PASSTHROUGH is not set. Please define it in your local Makefile or environment. \
	Example: DEPS_VAR_PASSTHROUGH="VAR1 VAR2 VAR3")
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
			pass_through_vars="WITH_DEPS=1"; \
			for var in $(DEPS_VAR_PASSTHROUGH); do \
				pass_through_vars="$$pass_through_vars $$var=$${!var}"; \
			done; \
			env -i HOME="$(HOME)" TERM="$(TERM)" $$pass_through_vars \
				$(MAKE) -C $$dep_path $* || exit $$?; \
		done; \
	fi
