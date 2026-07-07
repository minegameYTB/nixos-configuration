# NixOS Configuration — Agent Guide

## Project Overview
- Flake-based NixOS configuration with btrfs/ZFS support
- Modules: desktop (GNOME), gaming, VM host/guest, AI tools, LUKS encryption
- Dual install path: NixOS (full) + Home Manager standalone (non-NixOS Linux)

## Flake Architecture
- **`flake.nix`** — entrypoint: inputs, overlays, `specialArgs`, `mkMachine`, `mkHome`
- **`machine.nix`** — defines `mkMachine` → 10 NixOS configurations
- **`overlay.nix`** — injects NUR, CachyOS kernel, unstable/PR pkgs, `specialArgs`
- **Hardware profiles** set `marker.hostProfile` (desktop/server) and `marker.archProfile` (x86-64-v1..v4, amd-zen4, aarch64) via `configurations/modules/misc/marker.nix`

## Configuration Structure
```
configurations/
├── configuration.nix          # Core NixOS module (imports common configs)
├── config-modules/            # Distant flake modules (stylix, lanzaboote, flatpak, nix-index-db)
├── modules/                   # Custom modules (programs, misc markers, nix caches, vmware)
├── configs/
│   ├── common/                # Shared: users, pkgs, timezone, security, system-opts/*
│   ├── networking/
│   ├── overlays/              # Package overrides (mutters, coreutils, gnome-control-center)
│   ├── bootloader/            # systemd-boot, GRUB2 (EFI/BIOS), efi-mountpoint
│   ├── specific/              # Machine features: desktop (gnome, games, browser), VM guest/host, AI, container
│   └── system/                # Services (flatpak, channel cleanup), /tmp modes
├── hardware-configuration/
│   ├── filesystem/            # btrfs, zfs, luks-btrfs mount/config
│   ├── machines/              # hp-probook, hp-240, vm
│   └── specific/              # intel-firmware, nvidia, swap
├── disko-configuration/       # 4 active + 4 unused disko configs
└── patch/nixpkgs/             # Out-of-tree patches for libvirt, qemu
```

## Key Patterns

### The `marker` Module
- `marker.hostProfile` (desktop|server) and `marker.archProfile` set in `hardware-configuration.nix`
- Consumed by `cachyos-kernel.nix` for kernel selection (desktop=LTO+BORE, server=LTS)

### CachyOS Kernel
- Desktop uses `linux_cachyos-lto` (bore scheduler), server uses `linux_cachyos-server-lto`
- Supports micro-arch pinning (v2/v3/v4/amd-zen4) via arch suffix
- ARM falls back to stock nixpkgs kernel
- Custom build options via `hardware.cachyos.kernelBuildConfig`

### Home Manager
- Two modes: **NixOS-managed** (via `home-manager.nixosModule`) and **standalone** (via `nix run home-manager/master -- init`)
- Desktop profile: `home.nix` + customization (theme, apps, cli) + gui-packages
- Server profile: `home.nix` + common + cli-app
- Standalone mode uses `targets.genericLinux.enable` + NUR overlay + nix GC

## Install System (`install-lib/`)
- **`install.sh`** — auto-detects NixOS vs standalone Linux
- **`nixos-install.sh`** — 10-step system with checkpoint/resume
  - Steps: INTERACTIVE_SETUP → LUKS_SETUP → PARTITION → ZFS_TUNE → LUKS_PASSPHRASE → SWAP → NIXOS_INSTALL → PASSWORD → COPY_CONFIG → ZFS_EXPORT
  - Temp swap: btrfs (mkswapfile), ZFS (zvol), ext4/other (fallocate)
- **`hm-standalone-install.sh`** — standalone HM install on any Linux
- **Checkpoint system** (`checkpoint.sh`): state file in `/tmp/nixos-install-state`, persists interactive answers, survives crashes
- LUKS+ZFS removed — ZFS selection silently skips LUKS prompt in `step_interactive_setup`

## Testing
- `script/test-install-logic.sh` — 64 tests covering disko selection, swap types, cleanup, ARC tuning, variables, flags, step system
- Run: `bash script/test-install-logic.sh`

## Development Workflow
- `nix build .#nixosConfigurations.<name>.config.system.build.toplevel` — build a config
- `sudo nixos-rebuild switch --flake .#<name>` — deploy
- `nix develop` — dev shell (via `build.sh` or flake)
- `make run-deadnix` — find unused nix code
- `make run-shellcheck` — lint shell scripts

## Critical Context
- **No secrets in repo**: initial passwords are "nixos", LUKS keys are generated at install time
- **Blocklist disabled**: StevenBlack/hosts nixpkgs module has an issue, commented out in networking
- **nixpkgs-main** = release-26.05, pinned in flake.lock
- **nixpkgs-pr** = staging-next for testing PRs (libvirt, qemu updates)
- **forceImportRoot = false** for ZFS (both LUKS+ZFS and plain ZFS)
- **NixOS stateVersion**: system = 26.05, HM = 26.05
- **Patches in repo**: `configurations/patch/nixpkgs/` but integration happens via `nixpkgs-patched` in flake.nix using PRs
