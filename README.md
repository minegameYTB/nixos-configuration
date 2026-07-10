# Nixos-configuration

This configuration use a stable version of NixOS

---
### Minimum requirements

| Component | Requirement |
|-----------|-------------|
| **RAM (btrfs)** | 4 GiB + swap (detected automatically if < 8 GiB) |
| **RAM (ZFS)** | 16 GiB recommended. 8 GiB minimum but may be tight during nixos-rebuild |
| **Disk** | 50 GiB+ (more for games/large packages) |
| **Boot** | UEFI (BIOS only for btrfs VMs) |

> The install script detects RAM and creates temporary swap automatically on btrfs.
> ARC is capped at 2 GiB during install.
> ARC can be reduced further with `ZFS_ARC_MAX_GiB=1 ./install.sh` on low-RAM machines.

---
### Installation

Clone this repository (preferably in your home directory) on your NixOS installation media
`git clone https://github.com/minegameytb/nixos-configuration`

How to install this flake with nixos-install ?
(on the new partition (mounted on /mnt))

The documentation of install script is [here](INSTALL.md)

#### Manual installation
```bash
### With the flake on local
#> nix-shell -p disko
#> disko -m destroy,format,mount nixos-configuration/configurations/disko-configuration/current/<configuration type>.nix --argstr device /dev/<device> --argstr size <size (fixed or %)> (eventually --argstr keyFile </path/to/keyfile>)
#> nixos-install --flake .#<host>

### Distant flake
#> nix-shell -p disko
#> wget https://raw.githubusercontent.com/minegameYTB/nixos-configuration/refs/heads/flake/configurations/disko-configuration/current/<configuration type>.nix
#> disko -m destroy,format,mount ./<configuration type>.nix --argstr device /dev/<device> --argstr size <size (fixed or %)> (eventually --argstr keyFile </path/to/keyfile>)
#> nixos-install --flake github:minegameYTB/nixos-configuration#<host>

### To only mount with disko (without clobbering existing data):
#> nix-shell -p disko
#> disko -m mount ./configurations/disko-configuration/current/<configuration type>.nix --argstr device /dev/<device>
```

#### Automated installation (NixOS and Home Manager)
```bash
### with root for NixOS
#> ./install.sh

### Without root (home manager on traditional Linux distribution)
$> ./install.sh
```
---
## Flake structure

```
nixos-configuration/
├── flake.nix              # Entrypoint: inputs, overlays, specialArgs, mkMachine, mkHome
├── machine.nix            # Defines 10 NixOS configurations via mkMachine
├── overlay.nix            # Global overlays (NUR, CachyOS, unstable/PR packages)
├── install.sh             # Auto-detecting install script (NixOS / HM standalone)
├── Makefile / build.sh    # Automation + nix-shell wrapper
│
├── configurations/        # Complete NixOS configuration
│   ├── configuration.nix  # Core NixOS module (imports common configs)
│   ├── config-modules/    # Distant flake modules (stylix, lanzaboote, flatpak, nix-index-db)
│   ├── modules/           # Custom modules (programs, marker, caches, vmware)
│   ├── configs/
│   │   ├── common/        # Shared: users, pkgs, timezone, security, system-opts
│   │   ├── specific/      # Desktop (GNOME, games, browser), VM guest/host, AI, container
│   │   ├── overlays/      # Package overrides (mutter, coreutils, gnome-control-center)
│   │   ├── bootloader/    # systemd-boot, GRUB2 (EFI/BIOS)
│   │   └── system/        # Services (flatpak, channel cleanup), /tmp modes
│   ├── hardware-configuration/
│   │   ├── filesystem/    # btrfs, zfs, luks-btrfs mount/config
│   │   ├── machines/      # hp-probook, hp-240, vm
│   │   └── specific/      # intel-firmware, nvidia, swap
│   ├── disko-configuration/  # 4 active + 4 unused configs
│   └── patch/nixpkgs/     # Out-of-tree patches (libvirt, qemu)
│
├── profiles/              # Machine profiles
│   ├── hp-probook-profile.nix
│   ├── hp-240-profile.nix
│   ├── vm-*-profile.nix   (6 VM profiles)
│   └── base-profiles/     # Shared VM bases (desktop, server)
│
├── hm-profiles/           # Home Manager profiles (desktop, server)
│
├── home-manager/          # Home Manager configuration
│   ├── home.nix           # Core HM module
│   ├── config-modules/    # lazyvim, zen-browser
│   └── configs/           # common, customization, desktop, specific (nixos/standalone)
│
├── install-lib/           # Install scripts (defaults, checkpoint, lib, nixos-install, hm-standalone)
│
├── pkgs/                  # Local packages (fhsEnv, rm-only, sshrm)
│
├── script/                # Utility scripts (mksymlink, update-flake, deadnix, shellcheck, tests)
│
└── example/               # Packaging examples
```
