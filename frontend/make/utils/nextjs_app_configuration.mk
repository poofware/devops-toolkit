# --------------------------------
# Next.js App Configuration
# --------------------------------

SHELL := bash

# Check that the current working directory is the root of a Next.js app
ifeq ($(wildcard package.json),)
  $(error Error: package.json not found. Please ensure you are in the root directory of your Next.js app.)
endif

# Include shared frontend configuration
ifndef INCLUDED_FRONTEND_APP_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/utils/frontend_app_configuration.mk
endif


INCLUDED_NEXTJS_APP_CONFIGURATION := 1
