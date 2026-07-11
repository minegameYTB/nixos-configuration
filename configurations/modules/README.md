# Modules

Custom NixOS modules (programs, markers, caches, vmware).

## Usage

In a machine profile, add:
```
../configurations/modules
```

In `configuration.nix` (shared across all machines):
```
./modules
```

This imports `default.nix` which collects all sub-modules automatically. See `configurations/modules/default.nix` for the full list.
