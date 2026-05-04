# Install script — documentation

## Overview

This script automates the installation of a NixOS configuration (or Home Manager standalone on non-NixOS systems) from a flake. It detects the host environment, partitions and formats the disk via disko, optionally sets up LUKS encryption, and runs `nixos-install`.

**Entry point:** `install.sh`
**Library directory:** `install-lib/`

```
install.sh
install-lib/
  lib.sh                   # shared variables and helper functions
  nixos-install.sh         # NixOS install path
  hm-standalone-install.sh # Home Manager standalone install path (non-NixOS)
```

---

## Requirements

- Bash 4+
- `jq` (flake.lock parsing)
- `curl` (installed automatically on supported distros if missing — HM path only)
- `nix` with flakes enabled (installed automatically — HM path only)
- `lsblk`, `findmnt`, `blkid` (standard Linux utilities)
- **NixOS path only:** must be run as root (`sudo ./install.sh`)

---

## Usage

```bash
sudo ./install.sh
```

The script auto-detects the environment:

- **NixOS** (`/etc/NIXOS` + `/run/current-system` present) → NixOS install path
- **Other Linux** → Home Manager standalone install path
- **Non-Linux** → exits with error

---

## Environment variables

These variables can be set before running the script to adjust its behaviour without editing any file.

### Swap

| Variable | Default | Description |
|---|---|---|
| `SWAP_THRESHOLD_GiB` | `4` | RAM threshold in GiB below which a temporary swap is created |
| `SWAP_SIZE_MiB` | `8192` | Swap size in MiB |
| `FORCE_SWAP` | *(unset)* | `1` = always create swap · `0` = never create swap |

**Examples:**

```bash
# Default behaviour: swap created only if RAM < 4 GiB
sudo ./install.sh

# Always create swap (useful on machines with fast but limited RAM)
FORCE_SWAP=1 sudo ./install.sh

# Never create swap
FORCE_SWAP=0 sudo ./install.sh

# Raise the threshold to 8 GiB
SWAP_THRESHOLD_GiB=8 sudo ./install.sh
```

### Output

| Variable | Default | Description |
|---|---|---|
| `NO_COLOR` | *(unset)* | Set to any value to disable ANSI colour output |

---

## NixOS install path — step by step

Triggered when `/etc/NIXOS` and `/run/current-system` are both present.

1. **Root check** — exits if not run as root.
2. **RAM detection** — reads `/proc/meminfo`, evaluates whether a temporary swap is needed based on `SWAP_THRESHOLD_GiB` / `FORCE_SWAP`.
3. **Boot method detection** — checks `/sys/firmware/efi/fw_platform_size` to pick UEFI or BIOS disko configuration.
4. **Encryption prompt** — UEFI only: asks whether to use a LUKS-encrypted layout.
5. **Disk selection** — lists available block devices, prompts for target device then size (accepts formats like `100%` or `50G`).
6. **Profile selection** — runs `nix flake show` and prompts for the NixOS profile name.
7. **5-second countdown** — last chance to abort before destructive operations begin.
8. **Disko** — partitions, formats and mounts the target disk according to the selected `.nix` configuration.
9. **LUKS passphrase** (optional) — if encryption was chosen and a passphrase was requested, adds it as a second LUKS key slot.
10. **Temporary swap** — if `needSwap` is set, creates a swapfile on `/mnt` sized to total RAM. Filesystem-aware (see below).
11. **`nixos-install`** — installs the flake configuration onto the mounted disk.
12. **Swap teardown** — deactivates and removes the temporary swapfile.

### Disko configuration files

Located in `configurations/disko-configuration/current/`:

| File | Boot | Encryption |
|---|---|---|
| `disko-efi-btrfs.nix` | UEFI | None |
| `disko-efi-luks-btrfs.nix` | UEFI | LUKS |
| `disko-bios-btrfs.nix` | BIOS | None |

---

## LUKS encryption

When encryption is selected, `setupLuksEncryption` handles key provisioning:

- **Generate a random key** → stored either as a file (`/tmp/secret.key`) or written directly to a raw partition/device
- **Use an existing key** → provide the path to a key file or device
- **Optional passphrase** → added as a second LUKS key slot via `cryptsetup luksAddKey`, with configurable key size (default: 4096 bits)

> **Warning:** when using a raw partition as key device, its contents are overwritten immediately.

---

## Temporary swap

The swap mechanism exists because `nixos-install` evaluates the entire flake in memory, which can exhaust RAM on low-memory machines.

### Decision logic

```
FORCE_SWAP=1  →  swap always created
FORCE_SWAP=0  →  swap never created
RAM < SWAP_THRESHOLD_GiB  →  swap created
RAM ≥ SWAP_THRESHOLD_GiB  →  swap skipped
```

### Filesystem handling

The swapfile is created at `/mnt/.swapfile-install` with a fixed size of 8 GiB — large enough for flake evaluation regardless of how much RAM the machine has.

**btrfs** — `fallocate` cannot be used because btrfs Copy-on-Write does not guarantee contiguous blocks, which the kernel requires for swap. Instead, `btrfs filesystem mkswapfile` is used — it handles COW disabling, block allocation, and swap initialisation in a single command. Requires btrfs-progs ≥ 6.1 (available on any recent NixOS ISO).

```bash
btrfs filesystem mkswapfile --size <size>M /mnt/.swapfile-install
```

**ext4, xfs, and others** — `fallocate` is used directly, which is near-instant.

After `nixos-install` completes, the swapfile is deactivated (`swapoff`) and deleted. The teardown function is a no-op if swap was never created.

---

## Home Manager standalone path

Triggered on any non-NixOS Linux system.

1. Reads the nixpkgs channel from `flake.lock` to select the matching `home-manager` branch (`release-X.Y` or `master` for unstable).
2. Installs `curl` if missing (supported: `ubuntu`, `debian`, `linuxmint`, `pop`, `fedora`, `almalinux`).
3. Installs Flatpak system-wide and registers the Flathub remote (`--system`). Skipped with a warning on unsupported distros. App management itself is handled by the HM module — this only sets up the system layer.
4. Installs Nix via the [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer) with `--prefer-upstream-nix`.
5. Initialises the first Home Manager generation (`hm init --switch`).
6. Detects system architecture (`x86_64-linux` or `aarch64-linux`).
7. Reads the default username from `flake.nix` (`users = [ "..." ]`) and prompts for confirmation.
8. Runs `home-manager switch` with the resolved `username@arch` flake target.

---

## Helper functions (lib.sh)

| Function | Description |
|---|---|
| `info <msg>` | Prints a cyan `info:` prefixed message to stdout |
| `warn <msg>` | Prints a magenta `warning:` prefixed message to stderr |
| `run_command <cmd...>` | Prints the command in yellow then executes it |

`nixFlags` and `nixpkgsRev` are global variables sourced from `lib.sh` and used across both install paths.
