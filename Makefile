# -- Build variable and "fake target" --
NIX_FLAGS=--extra-experimental-features "nix-command flakes"
SCRIPT_DIR=$(shell pwd)/script
.PHONY: help update-flake mksymlink run-deadnix

# -- Use help target by default (use '#' 3 times to show comment for help) --
.DEFAULT_GOAL := help

help:           ### Show help
	@echo -e "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?### .*$$' $(MAKEFILE_LIST) | awk '{printf "  \033[36m%-15s\033[0m %s\n", $$1, substr($$0, index($$0, "###") + 3)}'

update-flake:   ### update-flake
	bash -c $(SCRIPT_DIR)/update-flake

mksymlink:      ### Make symlink
	bash -c $(SCRIPT_DIR)/mksymlink

run-deadnix:    ### Run deadnix (remove unused declaration in nix expressions)
	bash -c $(SCRIPT_DIR)/run-deadnix
