# -- Build variable and "fake target" --
NIX_FLAGS=--extra-experimental-features "nix-command flakes"
SCRIPT_DIR=$(shell pwd)/script
.PHONY: help update-flake update-flake-local mksymlink run-deadnix run-shellcheck env iso-gnome iso-minimal iso-all

# -- Use help target by default (use '#' 3 times to show comment for help) --
.DEFAULT_GOAL := help

help:           ### Show help
	@echo -e "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?### .*$$' $(MAKEFILE_LIST) | awk '{printf "  \033[36m%-15s\033[0m %s\n", $$1, substr($$0, index($$0, "###") + 3)}'

update-flake:   ### update-flake
	bash "$(SCRIPT_DIR)/update-flake"

update-flake-local:   ### update-flake without git (testers, no commit/push)
	bash "$(SCRIPT_DIR)/update-flake-local"

mksymlink:      ### Make symlink
	bash "$(SCRIPT_DIR)/mksymlink"

run-deadnix:    ### Run deadnix (remove unused declaration in nix expressions)
	bash "$(SCRIPT_DIR)/run-deadnix"

run-shellcheck: ### Run shellcheck on Bash entrypoints
	bash "$(SCRIPT_DIR)/run-shellcheck"

env:            ### Build tight per-service envs and list their bins
	@for e in core pending root health main; do \
	  echo "=== nixos-auto-update-env-$$e ==="; \
	  out=$$(nix $(NIX_FLAGS) build ".#nixos-auto-update-env-$$e" --print-out-paths 2>&1 | tail -1); \
	  ls -1 "$$out/bin" | tr '\n' ' '; echo; echo; \
	done
	@echo "System-wired envs (single PATH per service):"
	@for svc in nixos-auto-update nixos-auto-update-notify-failure nixos-autoupdate-healthcheck; do \
	  path=$$(nix $(NIX_FLAGS) eval --raw ".#nixosConfigurations.vm-desktop-efi.config.systemd.services.$$svc.environment.PATH" 2>&1); \
	  echo "  $$svc: $$path"; \
	done
	@pending=$$(nix $(NIX_FLAGS) eval --raw ".#nixosConfigurations.vm-desktop-efi.config.systemd.user.services.nixos-auto-update-notify-pending.environment.PATH" 2>&1); \
	echo "  nixos-auto-update-notify-pending: $$pending"

iso-gnome:      ### Build GNOME ISO → /tmp/iso-gnome.iso
	bash "$(SCRIPT_DIR)/build-iso-gnome"

iso-minimal:    ### Build CLI ISO → /tmp/iso-minimal.iso
	bash "$(SCRIPT_DIR)/build-iso-minimal"

iso-all:        ### Build both ISOs (sequential)
	@$(MAKE) iso-gnome
	@$(MAKE) iso-minimal
