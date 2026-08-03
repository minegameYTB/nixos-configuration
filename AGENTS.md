# NixOS Configuration — Agent Guide

## Project Overview
- Flake-based NixOS configuration with btrfs/ZFS support
- Modules: desktop (GNOME), gaming, VM host/guest, AI tools, LUKS encryption
- Dual install path: NixOS (full) + Home Manager standalone (non-NixOS Linux)
- ISO builder: 2 variants (GNOME / CLI) with `mkIso` helper, auto-discovered as flake packages

## Flake Architecture
- **`flake.nix`** — entrypoint: inputs, overlays, `specialArgs`, `mkMachine`, `mkHome`
- **`machine.nix`** — defines `mkMachine` → 11 NixOS configurations + 2 ISO configs via `helpers.iso.mkIso`
- **`overlay.nix`** — injects NUR, CachyOS kernel, unstable/PR pkgs, `pkgsConfig` (delegates to `pkgs/default.nix`)
- **`lib/nixpkgs-patches.nix`** — single source for the `pkgsPatched` patch list (PR patches via `pkgs.fetchpatch` — normalized hashes, stable across PR updates; local patches from `configurations/patch/nixpkgs/`)
- **`lib/default.nix`** — re-exports `machine.nix` (`mkMachine`) and `iso/common.nix` (ISO helpers)
- **`lib/repo.nix`** — single source for `repoUrl`, used by packaging, `/etc/os-release`, and install clone
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

iso/                           # ISO profiles (common, gnome, cli)
lib/                           # Helper re-exports (machine.nix, iso/common.nix, nixpkgs-patches.nix, repo.nix)
pkgs/                          # Local packages (default.nix is single source of truth for overlay + flake)
  nixos-config/                #   nixos-config-install wrapper + .config-repo generation
install-lib/                   # Install scripts (defaults, checkpoint, lib, nixos-install, hm-standalone)
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

### ISO Profiles (`iso/`)
- **`iso/common.nix`** — `mkIsoConfig` (shared NixOS module for all ISOs), `mkIso` (nixosSystem builder), keyboard helpers, welcome message
- **`iso/gnome.nix`** — GNOME desktop variant (imports desktop, sound, browser, autologin)
- **`iso/cli.nix`** — Minimal CLI variant (only shared config + console keymap)
- **`machine.nix`** — ISO configs registered via `helpers.iso.mkIso { edition, profile, hostname, hmProfile, ... }`
- **Auto-discovery** — every config starting with `iso-` in `machine.nix` is automatically exposed as a flake package via `filterAttrs` + `mapAttrs'` in `flake.nix`
- See `doc/ISO.md` for full docs

## Documentation
- All documentation lives in [`doc/`](doc/) — `INSTALL.md`, `ISO.md`, `HM.md`, `modules.md`, `config-modules.md`
- `AGENTS.md` (this file) stays at the project root for agent discovery

### Repo URL — `lib/repo.nix`
- Single source for `repoUrl`, imported by `flake.nix` (packaging), `version.nix` (`CONFIG_URL` in `/etc/os-release`), and `install-lib/nixos-install.sh` (config clone into installed system)
- `.config-repo` (URL + rev) generated in the `nixos-config` derivation for the ISO
- Overridable at runtime via `INSTALL_REPO_URL` (env variable)

### Home Manager
- **Two modes**: NixOS-managed (via `home-manager.nixosModule`) and **standalone** (via `mkHome` in `flake.nix`)
- **Single entry point**: `hm-profiles/users/entry.nix` reads `globalFeatures` + per-user `hmFeatures` → imports `home-manager/features/<name>.nix`
- **Users**: defined in `hm-profiles/users.nix` with `description` + `hmFeatures` list. Per-user overrides in `hm-profiles/users/<name>/`
- **Features** (`home-manager/features/`): HM modules activated by name. Simple features inline; complex ones delegate to `home-manager/config-modules/<name>/` via `(inputs.self + "/home-manager/config-modules/<name>")`
- **Modules** (`home-manager/config-modules/`): external flake module wrappers (lazyvim, zen-browser), source of truth referenced by features
- **ISO**: uses `hmFeatures` directly in `machine.nix` → `mkIso { hmFeatures = [...]; }` → user `nixos` in ISO
- See `doc/HM.md` for full docs

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
- `nix build '.#iso-gnome'` — build GNOME ISO
- `nix build '.#iso-minimal'` — build CLI ISO
- **Use `/tmp/opencode` as the preferred temporary directory** for scratch work and experiments

## Critical Context
- **No secrets in repo**: initial passwords are "nixos", LUKS keys are generated at install time
- **Blocklist disabled**: StevenBlack/hosts nixpkgs module has an issue, commented out in networking
- **nixpkgs-main** = release-26.05, pinned in flake.lock
- **nixpkgs-pr** = staging-next for testing PRs (libvirt, qemu updates)
- **forceImportRoot = false** for ZFS (both LUKS+ZFS and plain ZFS)
- **NixOS stateVersion**: system = 26.05, HM = 26.05
- **Patches in repo**: `configurations/patch/nixpkgs/` but integration happens via `nixpkgs-patched` in flake.nix using PRs
