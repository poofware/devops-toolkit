# ----------------------
# Help Target
# ----------------------

SHELL := /bin/bash

.PHONY: _help

INCLUDED_HELP := 1


_help:
	@echo "Available targets:"; \
	awk 'BEGIN { FS=":.*" } \
	     /^##/ { desc = substr($$0, 4); next } \
	     /^[^_][a-zA-Z0-9_-]*:/ { \
	       if (desc != "") { \
	         tmp = desc; gsub(/[# ]/, "", tmp); \
	         if (length(tmp) > 0) { printf "\033[36m%-20s\033[0m %s\n", $$1, desc } \
	       } \
	       desc = "" \
	     }' $(MAKEFILE_LIST) | sort

