## Lists available targets
help:
	@echo "Available targets:"
	@awk 'BEGIN {FS=":.*"} /^[a-zA-Z0-9_-]+:/ {if (desc) printf "\033[36m%-20s\033[0m %s\n", $$1, desc; desc="";} /^##/ {desc=substr($$0, 4)}' $(MAKEFILE_LIST) | sort
	@echo
	@echo "Note:"
	@echo "- Any target can be run with the WITH_DEPS=1 flag to perform that same target recursively on all dependency services of this service."
