### Variable
NIX_FLAGS="--extra-experimental-features nix-command --extra-experimental-features flakes"
SCRIPT_DIR="$(shell pwd)/script"

### Check files
check:
	nix $(NIX_FLAGS) flake check --no-build

### update-flake
update-flake:
	bash -c $(SCRIPT_DIR)/update-flake

### Make symlink
mksymlink:
	bash -c $(SCRIPT_DIR)/mksymlink

### Fix nix syntax
fix:
	bash -c $(SCRIPT_DIR)/fix-syntax
