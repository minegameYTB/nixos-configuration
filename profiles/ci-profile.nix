{ lib, pkgs, ... }:

{
  imports = [ ./vm-cli-profile.nix ];

  # CI: vanilla NixOS kernel, no CachyOS LTO/BORE — faster, smaller, binary cache.
  # Overrides configurations/configs/common/system-opts/cachyos-kernel.nix (which
  # picks linuxPackages-cachyos-* via marker.hostProfile/archProfile). mkForce wins.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
}
