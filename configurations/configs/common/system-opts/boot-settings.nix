{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
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
    kernelPackages =
      let
        # Customise CachyOS kernel to use helper expression
        helpers = pkgs.callPackage "${inputs.nix-cachyos-kernel.outPath}/helpers.nix" { };
      in
      if config.hostProfile == "desktop" then
        # Use "helpers.kernelModuleLLVMOverride" with lto variant bcause lto use clang as compiler
        helpers.kernelModuleLLVMOverride pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto
      else
        helpers.kernelModuleLLVMOverride pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;
    kernelPatches = [
      #{
      #  # https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f4c50a4034e6
      #  name = "patch-xfrm-f4c50a4";
      #  patch = (
      #    pkgs.fetchurl {
      #      url = "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/patch/?id=f4c50a4034e62ab75f1d5cdd191dd5f9c77fdff4";
      #      hash = "sha256-j5l548aKMPIxfSfwy4hJadBvQN2kZsutpOVjLSXSk0A=";
      #    }
      #  );
      #}
    ];
  };

  ### Add substituer from CachyOS 3th part source (binary)
  nix.settings = {
    substituters = [
      "https://attic.xuyh0120.win/lantian"
    ];
    trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };
}
