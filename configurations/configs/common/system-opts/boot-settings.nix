{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Add cachyOS kernel expression
  imports = [ ./cachyos-kernel.nix ];

  ### Boot config (followed this guide for hardening: https://madaidans-insecurities.github.io/guides/linux-hardening.html)
  boot = {
    # Define size for /dev directory
    devSize = "16m";
    binfmt = {
      preferStaticEmulators = true;
      addEmulatedSystemsToNixSandbox = true;
      emulatedSystems = [
        "aarch64-linux"
      ];
    };
    initrd.systemd = {
      #enable = true; # Now default in NixOS 26.05
      emergencyAccess = "$y$j9T$CmuNpg/fSyEMO8pehMLwU.$Oe7w2sKzs6teBwP5rU.OOVeGyMAHKL8Pz3JunPlLOv/";
    };
    consoleLogLevel = 0;
  };
}
