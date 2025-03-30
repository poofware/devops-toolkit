# --------------------------------
# Go Mod Vendor
# --------------------------------

SHELL := /bin/bash

INCLUDED_GO_MOD_VENDOR := 1


ifndef INCLUDED_ENSURE_GO
  include devops-toolkit/backend/make/utils/ensure_go.mk
endif


## Creates vendor directory and updates it based on changes in go.mod or go.sum
_go-mod-vendor: _ensure-go go.mod go.sum
	@echo "[INFO] [Go Mod Vendor] Updating vendor directory due to non-existence or changes in go.mod or go.sum..."
	go mod vendor
	@echo "[INFO] [Go Mod Vendor] Done. Vendor directory updated successfully."
