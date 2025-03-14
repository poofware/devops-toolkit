# ---------------------------------------
# Constants for HCP (HashiCorp Cloud Platform) configuration
#
# These constants are not sensitive, and hence, are made available for Poof backend services.
# ---------------------------------------

SHELL := /bin/bash


# To force a static assignment operation with '?=' behavior, we wrap the ':=' assignment in an ifndef check
ifndef HCP_ENCRYPTED_API_TOKEN
	export HCP_ENCRYPTED_API_TOKEN := $(shell devops-toolkit/backend/scripts/fetch_hcp_api_token.sh encrypted)
endif

# Poof
export HCP_ORG_ID := a4c32123-5c1c-45cd-ad4e-9fe42a30d664
# Backend
export HCP_PROJECT_ID := d413f61e-00f1-4ddf-afaf-bf8b9c04957e
