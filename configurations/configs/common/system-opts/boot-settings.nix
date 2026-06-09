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
        helpers = pkgs.callPackage "${inputs.nix-cachyos-kernel.outPath}/helpers.nix" { };
        host = config.marker.hostProfile; # "desktop" / "server"
        arch = config.marker.archProfile; # "x86-64-v3" or "aarch64"

        isArm = arch == "aarch64" || pkgs.stdenv.hostPlatform.isAarch64;

        # suffix only for desktop x86, server stays on v1
        desktopSuffix =
          {
            "x86-64-v1" = "";
            "x86-64-v2" = "-x86_64-v2";
            "x86-64-v3" = "-x86_64-v3";
            "x86-64-v4" = "-x86_64-v4";
          }
          .${arch} or "";

        suffix = if host == "desktop" && !isArm then desktopSuffix else "";

        base =
          if host == "desktop" then "linuxPackages-cachyos-bore-lto" else "linuxPackages-cachyos-server-lto";

        cachyName = base + suffix;
        cachyKernel = pkgs.cachyosKernels.${cachyName} or null;
      in
      if isArm then
        # no CachyOS on ARM → use stock NixOS kernel
        pkgs.linuxPackages_latest
      else if host == "server" && arch != "x86-64-v1" && arch != "generic" then
        # explicit guard: server kernel exists only as v1
        throw "kernelPackages: CachyOS server kernel only provides x86-64-v1, got ${arch}"
      else if cachyKernel != null then
        helpers.kernelModuleLLVMOverride cachyKernel
      else
        throw "kernelPackages: ${cachyName} not found for ${arch}";
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
