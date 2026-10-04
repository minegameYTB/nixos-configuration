# Pinned vanilla kernel: same version as the fleet's CachyOS kernels (7.2.8),
# minus the CachyOS patches, with the stock NixOS defconfig.
#
# Purpose: frozen reference point. If a CachyOS/nixpkgs kernel update
# misbehaves, boot this to tell a packaging/patch problem apart from an
# upstream regression. ZFS-compatible (unlike linux-next), so it can also
# serve as a fallback on ZFS machines.
#
# To re-pin to another stable release: take version + hash from
# pkgs/os-specific/linux/kernel/kernels-org.json in nixpkgs and update
# `version` + `hash` below (`src.url` and `modDirVersion` follow `version`
# automatically; verify the tarball with `nix store prefetch-file <url>`).
{
  lib,
  fetchurl,
  buildLinux,
  ...
}@args:

buildLinux (
  args
  // rec {
    version = "7.2.8";
    modDirVersion = version;

    src = fetchurl {
      url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
      hash = "sha256-EujVqXPRrXxaXGmILkAisTHtcV23AD/c12Dd+MPlGUE=";
    };

    kernelPatches = [ ];

    isLTS = false;
    extraMeta.branch = "7.2";
  }
  // (args.argsOverride or { })
)
