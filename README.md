# Nixos-configuration

This configuration use a stable version of NixOS

---
### Minimum requirements

| Component | Requirement |
|-----------|-------------|
| **RAM (btrfs)** | 4 GiB + swap (detected automatically if < 8 GiB) |
| **RAM (ZFS)** | 8 GiB (ZFS does not support swapfiles; zvol swap is created during install) |
| **Disk** | 50 GiB+ (more for games/large packages) |
| **Boot** | UEFI (BIOS only for btrfs VMs) |

> The install script detects RAM and creates temporary swap automatically on btrfs.
> On ZFS, a temporary zvol is used instead and ARC is capped at 2 GiB during install
> — compatible with all RAM sizes but 8 GiB+ is recommended.

---
### Installation

clone this repository (preferably in your home directory) on your NixOS installation
`git clone https://github.com/minegameytb/nixos-configuration`

How to install this flake with nixos-install ?
(on the new partition (mounted on /mnt))

The documentation of install script is [here](INSTALL.md)

#### Manual installation
```bash
### With the flake on local
#> nix-shell -p disko
#> disko -m destroy,format,mount nixos-configuration/configurations/disko-configuration/current/<configuration type>.nix --arg device '"/dev/<device>"'
#> nixos-install --flake .#<host>

### Distant flake
#> nix-shell -p disko
#> wget https://raw.githubusercontent.com/minegameYTB/nixos-configuration/refs/heads/flake/configurations/disko-configuration/current/<configuration type>.nix
#> disko -m destroy,format,mount ./configurations/disko-configuration/current/<configuration type>.nix --argstr device /dev/<device> --argstr size <size (fixed or %)> (eventually --argstr keyFile </path/to/keyfile (or /dev/<device1-..9>)
#> nixos-install --flake github:minegameYTB/nixos-configuration#<host>

### To only mount with disko (run nix command to obtain disko before):
#> disko -m mount ./configurations/disko-configuration/current/<configuration type>.nix --argstr device /dev/<device>
```

#### Automated installation (NixOS and Home Manager)
```bash
### with root for NixOS
#> ./install.sh

### Without root (home manager (on traditional linux distribution))
$> ./install.sh
```
---
## flake structure

this flake as a structure with mutiple directory

```
* nixos-configuration root 
|
 \_ configurations (all configuration that describe settings for NixOS (include flake specific modules and custom modules for this configuration))
|
 \_ home-manager (related to home-manager settings (to add package to user level))
|
 \_ pkgs (local nix expression for local packages)
|
 \_ profiles (a set of local expression to be used for a host (e.g: hp-probook will have "hp-probook" hostname while hp-240 will have "UTILISA-0SK6G4E" hostname))
|
 \_ flake.nix (local expression to describe this flake (nixpkgs version management uses flake.lock (which “fixes” package versions)))
|
\_ script (script folder)
 |
 \_ mksymlink (a simple script shell which will create a symlink into the root of home directory)
 |
 \_ update-flake (a shell script that will update the flake.lock file and create a git commit automatically)
```
