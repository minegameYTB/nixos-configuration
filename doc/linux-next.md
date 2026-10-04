# Custom test kernels (linux-next + pinned stable)

## Overview

Experimental, manually-pinned `linux-next` kernel (`7.3.0-rc5-next-20261002`
at the time of writing). Two usage paths share the same package:

- **Flake package** — `nix build '.#linux-next'` (kernel derivation only).
- **Test VM** — `vm-linux-next-efi` in `machine.nix` (CLI EFI, btrfs,
  hostname `nixos-kvm-srv-next`), which forces
  `boot.kernelPackages` to it via an inline module using
  `pkgs.pkgsConfig.linux-next`. No auto-update on that machine
  (moving-target kernel, manual testing only).

## Architecture

```
pkgs/linux-next/default.nix   # buildLinux + shallow fetchgit of linux-next.git
pkgs/linux-next/update.sh     # refresh the rev/hash/version pin
pkgs/default.nix              # exposes it as pkgsConfig.linux-next (=> '.#linux-next')
machine.nix                   # vm-linux-next-efi consumes pkgs.pkgsConfig.linux-next
```

Deliberately excluded: CachyOS patches/options (they don't apply to `-next`),
ZFS (doesn't build against `-next`, hence the btrfs-only test VM).
NixOS `common-config.nix` stays enabled so systemd/initrd requirements are met;
`ignoreConfigErrors = true` tolerates options that `-next` renamed or removed.

## Updating the pin

```bash
# Print the pin for current HEAD (read-only)
./pkgs/linux-next/update.sh

# Print the pin for a specific commit (e.g. a next-YYYYMMDD tag)
./pkgs/linux-next/update.sh --rev <sha1>

# Patch pkgs/linux-next/default.nix in place
./pkgs/linux-next/update.sh --write
```

Daily tags (`next-YYYYMMDD`) can be listed with
`git ls-remote --tags <url> 'next-*'` (use the `^{}` peeled commits).
`version` must equal the real `kernelrelease`
(`VERSION.PATCHLEVEL.SUBLEVEL` + `EXTRAVERSION` + `localversion*`) —
the script derives it from the prefetched source.

## Building

```bash
# Kernel only (iterate here on version/modDirVersion issues)
nix build '.#nixosConfigurations.vm-linux-next-efi.config.boot.kernelPackages.kernel' --no-link

# Bootable VM
nix build '.#nixosConfigurations.vm-linux-next-efi.config.system.build.vm'
```

Full build from source: ~30–60 min, ~20 GiB, no binary cache.

## Troubleshooting

- `modDirVersion X is wrong, it should be: Y` → set `version` to `Y`
  (or re-run `update.sh --write`, which computes it).
- Out-of-tree modules (`boot.extraModulePackages`) failing to compile
  against `-next` → disable them on the test VM case by case.
- `error: ... is not tracked by Git` → `git add` new files (flakes only
  see tracked files).

## Rollback

Stop building `vm-linux-next-efi`, or delete its entry from `machine.nix`.
Nothing else references the package.

## Pinned stable kernel (linux-pinned)

Frozen vanilla reference: same version as the fleet's CachyOS kernels
(`7.2.8`) minus the CachyOS patches, stock NixOS defconfig
(`pkgs/linux-pinned/default.nix`, exposed as `pkgsConfig.linux-pinned`
and flake package `.#linux-pinned`).

Use it when a kernel update misbehaves, to tell a packaging/patch problem
apart from an upstream regression. ZFS-compatible (unlike linux-next),
so it can also serve as a fallback on ZFS machines.

To point the test VM at it instead of linux-next, swap one line in the
`vm-linux-next-efi` inline module in `machine.nix`:

```nix
pkgs.linuxPackagesFor pkgs.pkgsConfig.linux-pinned
```

To re-pin to another stable release: take `version` + `hash` from
`pkgs/os-specific/linux/kernel/kernels-org.json` in nixpkgs (at the
revision locked in `flake.lock`) and update those two fields in
`pkgs/linux-pinned/default.nix` (`src.url` and `modDirVersion` follow
`version` automatically; verify the tarball with
`nix store prefetch-file <url>`).
