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

### Repo URL — `lib/repo.nix`
- Single source for `repoUrl`, imported by `version.nix` (`CONFIG_URL` in `/etc/os-release`) and `install-lib/nixos-install.sh` (config clone into installed system)
- `.config-repo` (URL + rev) generated in the `nixos-config` derivation for the ISO
- Overridable at runtime via `INSTALL_REPO_URL` (env variable)

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
  - `step_copy_config` supports 4 clone modes: `.git/` → full copy, `.config-repo` → `git clone --no-checkout` + checkout $rev, `lib/repo.nix` → shallow clone, fallback → copy without history
  - Temp swap: btrfs (mkswapfile), ext4/other (fallocate)
  - ZFS native encryption: generates 32-byte raw key, stores on raw partition or file
- **`hm-standalone-install.sh`** — standalone HM install on any Linux
- **Checkpoint system** (`checkpoint.sh`): state file in `/tmp/nixos-install-state`, persists interactive answers, survives crashes
- ZFS native encryption support was removed (see git history for `disko-efi-zfs-encrypted.nix` and `zfs-encrypted/` filesystem module)

### ZFS Native Encryption
- Datasets are encrypted with `aes-256-gcm` + `keyformat = "raw"` (32-byte key)
- `boot.zfs.requestEncryptionCredentials = true` triggers `zfs load-key -a` in initrd
- Key stored on a raw partition (e.g. SD card) at install time — read directly by initrd at boot
- `boot.initrd.kernelModules = [ "mmc_block" ]` ensures the key device is available
- Encrypted datasets: `ROOT` (covers `/`), `home`, `var` (covers `/var/log`, `/var/cache`, `/var/lib/libvirt`)
- Unencrypted: `nix` (performance), `reserved`
- The disko config's `postCreateHook` switches `keylocation` from the install-time temp path to the permanent raw device path

## Testing
- `script/test-install-logic.sh` — 68 tests covering disko selection, swap types, cleanup, ARC tuning, variables, flags, step system
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
