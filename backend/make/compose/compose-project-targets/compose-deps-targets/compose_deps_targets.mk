# --------------------
# Compose Deps Targets
# --------------------

SHELL := /bin/bash

.PHONY: _deps-%

# Check that the current working directory is the root of a project by verifying that the root Makefile exists.  
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

ifndef INCLUDED_COMPOSE_APP_CONFIGURATION
  $(error [ERROR] [Compose Deps Targets] The Compose Project Configuration must be included before any Compose Deps Targets.)
endif

ifdef INCLUDED_COMPOSE_PROJECT_TARGETS
  $(error [ERROR] [Compose Deps Targets] The Compose Project Targets must not be included before this file.)
endif


# ----------------------
# Targets
# ----------------------

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

ifndef INCLUDED_COMPOSE_DEPS_CLEAN
  include devops-toolkit/backend/make/compose/compose-project-targets/compose-deps-targets/compose_deps_clean.mk
endif
ifndef INCLUDED_COMPOSE_DEPS_BUILD
  include devops-toolkit/backend/make/compose/compose-project-targets/compose-deps-targets/compose_deps_build.mk
endif
ifndef INCLUDED_COMPOSE_DEPS_UP
  include devops-toolkit/backend/make/compose/compose-project-targets/compose-deps-targets/compose_deps_up.mk
endif
ifndef INCLUDED_COMPOSE_DEPS_DOWN
  include devops-toolkit/backend/make/compose/compose-project-targets/compose-deps-targets/compose_deps_down.mk
endif


INCLUDED_COMPOSE_DEPS_TARGETS := 1
