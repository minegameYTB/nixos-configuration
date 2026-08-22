# Nixos-configuration

Flake-based NixOS configuration with modular profiles, ISO builder, and dual install path (NixOS / Home Manager standalone).

## Getting started

### Automated install (recommended)

Build the ISO, write to a USB drive, boot, and run:

```bash
nix build '.#iso-gnome'
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

On the live ISO, open a terminal and run `nixos-config-install`.

### Direct install on any NixOS live ISO

```bash
nix build 'github:minegameYTB/nixos-configuration#nixos-config'
./result/bin/nixos-config-install
```

The install script detects NixOS vs other Linux and runs the appropriate path. See [doc/INSTALL.md](doc/INSTALL.md) for full documentation.

### Requirements

| Component | Minimum |
|-----------|---------|
| **RAM (btrfs)** | 4 GiB + temporary swap (auto if < 8 GiB) |
| **RAM (ZFS)** | 16 GiB recommended, 8 GiB minimum |
| **Disk** | 50 GiB+ |
| **Boot** | UEFI (BIOS supported for btrfs VMs) |

---

## ISO images

Two variants built from the flake:

```bash
nix build '.#iso-gnome'              # GNOME desktop
nix build '.#iso-minimal'            # Minimal CLI (headless)
```

Both include `nixos-config-install`. CachyOS kernel, ZFS support, dual keyboard layouts (US / FR). See [doc/ISO.md](doc/ISO.md) for architecture and creating new variants.

---

## Project structure

```
nixos-configuration/
├── flake.nix              # Entrypoint: inputs, overlays, specialArgs, mkMachine, mkHome
├── machine.nix            # Defines 11 NixOS configurations + ISO configs
├── overlay.nix            # Global overlays (NUR, CachyOS, unstable/PR, pkgsConfig)
├── install.sh             # Auto-detecting install script
├── build.sh               # nix-shell wrapper for make
│
├── configurations/        # NixOS configuration modules
├── profiles/              # Machine profiles (hp-probook, hp-240, VMs)
├── hm-profiles/           # Home Manager profiles (desktop, server)
├── home-manager/          # Home Manager modules
│
├── iso/                   # ISO profiles (common, gnome, cli)
├── lib/                   # Helper re-exports (machine.nix, iso/common.nix, repo.nix)
├── pkgs/                  # Local packages (nixos-config)
├── install-lib/           # Install script modules
├── script/                # Utility scripts (tests, linting)
├── doc/                   # Documentation (INSTALL, ISO, containers, modules)
└── example/               # Templates (packages, containers)
```

---

## Flake packages

| Name | Description |
|---|---|
| `nixos-config` | `nixos-config-install` wrapper + `.config-repo` generation |
| `iso-gnome` | GNOME desktop ISO |
| `iso-minimal` | CLI ISO |

Every NixOS config starting with `iso-` in `machine.nix` is auto-discovered as a flake package. No manual listing needed.

---

## Documentation

| File | Description |
|---|---|
| [doc/INSTALL.md](doc/INSTALL.md) | Install script — usage, flags, steps, environment variables |
| [doc/ISO.md](doc/ISO.md) | ISO profiles — architecture, building, keyboard specialisations, creating variants |
| [doc/containers.md](doc/containers.md) | Container stack — NixOS containers / Podman / nspawnctl, gates, adding containers & subsystems |
| [doc/modules.md](doc/modules.md) | Custom NixOS modules — usage and structure |
| [doc/config-modules.md](doc/config-modules.md) | Wrapper modules for external flake inputs |
| [doc/HM.md](doc/HM.md) | Home Manager architecture — users, features, config-modules |
| [AGENTS.md](AGENTS.md) | Agent guide — project overview for AI assistants |
