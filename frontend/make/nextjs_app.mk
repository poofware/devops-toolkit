# --------------------------------
# Next.js App
# --------------------------------

SHELL := bash

ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  $(error [toolkit] bootstrap.mk not included before $(lastword $(MAKEFILE_LIST)))
endif


# --------------------------------
# Internal Variable Declaration
# --------------------------------

ifndef INCLUDED_NEXTJS_APP_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/utils/nextjs_app_configuration.mk
endif

# --------------------------------
# Targets
# --------------------------------

ifndef INCLUDED_NEXTJS_APP_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/utils/nextjs_app_targets.mk
endif


INCLUDED_NEXTJS_APP := 1
