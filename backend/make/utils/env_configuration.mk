# -----------------------
# ENV Configuration
# -----------------------

SHELL := /bin/bash

INCLUDED_ENV_CONFIGURATION := 1


DEV_TEST_ENV := dev-test
DEV_ENV := dev
STAGING_TEST_ENV := staging-test
STAGING_ENV := staging
PROD_ENV := prod

ALLOWED_ENVS := $(DEV_TEST_ENV) $(DEV_ENV) $(STAGING_TEST_ENV) $(STAGING_ENV) $(PROD_ENV)

ifdef ENV
  ifeq (,$(filter $(ENV),$(ALLOWED_ENVS)))
    $(error ENV is set to an invalid value. Allowed values are: $(ALLOWED_ENVS))
  endif
else
  $(error ENV is not set. Please define it in your local Makefile or runtime/ci environment. \
    Example: ENV=dev, Options: $(ALLOWED_ENVS))
endif

export ENV
