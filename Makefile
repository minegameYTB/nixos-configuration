# -- Build variable and "fake target" --
NIX_FLAGS=--extra-experimental-features "nix-command flakes"
SCRIPT_DIR=$(shell pwd)/script
.PHONY: help update-flake mksymlink run-deadnix run-shellcheck iso-gnome iso-minimal iso-all

# -- Use help target by default (use '#' 3 times to show comment for help) --
.DEFAULT_GOAL := help

help:           ### Show help
	@echo -e "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?### .*$$' $(MAKEFILE_LIST) | awk '{printf "  \033[36m%-15s\033[0m %s\n", $$1, substr($$0, index($$0, "###") + 3)}'

update-flake:   ### update-flake
	bash "$(SCRIPT_DIR)/update-flake"

mksymlink:      ### Make symlink
	bash "$(SCRIPT_DIR)/mksymlink"

run-deadnix:    ### Run deadnix (remove unused declaration in nix expressions)
	bash "$(SCRIPT_DIR)/run-deadnix"

run-shellcheck: ### Run shellcheck on Bash entrypoints
	bash "$(SCRIPT_DIR)/run-shellcheck"

iso-gnome:      ### Build GNOME ISO → /tmp/iso-gnome.iso
	nix build $(NIX_FLAGS) --out-link /tmp/result-iso-gnome '.#iso-gnome'
	@ln -sf /tmp/result-iso-gnome/*.iso /tmp/iso-gnome.iso 2>/dev/null || true

iso-minimal:    ### Build CLI ISO → /tmp/iso-minimal.iso
	nix build $(NIX_FLAGS) --out-link /tmp/result-iso-minimal '.#iso-minimal'
	@ln -sf /tmp/result-iso-minimal/*.iso /tmp/iso-minimal.iso 2>/dev/null || true

iso-all:        ### Build les deux ISOs (séquentiel)
	@$(MAKE) iso-gnome
	@$(MAKE) iso-minimal
