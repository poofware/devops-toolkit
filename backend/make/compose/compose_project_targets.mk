# ------------------------------
# Compose Project Targets
# ------------------------------

SHELL := /bin/bash

# Check that the current working directory is the root of a project by verifying that the Makefile exists. 
ifeq ($(wildcard Makefile),)
  $(error Error: Makefile not found. Please ensure you are in the root directory of your project.)
endif

INCLUDED_COMPOSE_PROJECT_TARGETS := 1


# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_COMPOSE_DEPS
  include devops-toolkit/backend/make/compose/compose_deps.mk
endif
ifndef INCLUDED_COMPOSE_DOWN
  include devops-toolkit/backend/make/compose/compose_down.mk
endif
ifndef INCLUDED_COMPOSE_BUILD
  include devops-toolkit/backend/make/compose/compose_build.mk
endif
ifndef INCLUDED_COMPOSE_UP
  include devops-toolkit/backend/make/compose/compose_up.mk
endif
ifndef INCLUDED_COMPOSE_TEST
  include devops-toolkit/backend/make/compose/compose_test.mk
endif
ifndef INCLUDED_COMPOSE_CLEAN
  include devops-toolkit/backend/make/compose/compose_clean.mk
endif
ifndef INCLUDED_COMPOSE_CI
  include devops-toolkit/backend/make/compose/compose_ci.mk
endif
ifndef INCLUDED_COMPOSE_PROJECT_HELP
  include devops-toolkit/backend/make/compose/compose_project_help.mk
endif
