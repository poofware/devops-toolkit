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

_deps-%::
	@if [ "$(WITH_DEPS)" -eq 1 ] && [ -n "$(DEPS)" ]; then \
		for dep in $(DEPS); do \
			dep_path=$$(echo $$dep | cut -d: -f2); \
			dep_port=$$(echo $$dep | cut -d: -f3); \
			if [ ! -d "$$dep_path" ]; then \
				echo "[ERROR] [Deps-$*] Dependency '$$dep_path' found in DEPS does not exist."; \
				exit 1; \
			fi; \
			echo "[INFO] [Deps-$*] Running 'make $* -C $$dep_path' with passthrough vars and APP_PORT=$$dep_port..."; \
			env -i HOME="$(HOME)" TERM="$(TERM)" PATH="$(PATH)" MAKEFLAGS="$(MAKEFLAGS)" MAKELEVEL="$$(($(MAKELEVEL) + 1))" \
			$(foreach var,$(DEPS_PASSTHROUGH_VARS),$(var)="$($(var))") \
				$(MAKE) -C $$dep_path $* APP_PORT=$$dep_port || exit $$?; \
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
