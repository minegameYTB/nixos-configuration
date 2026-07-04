{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  boot = {
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
          if host == "desktop" then "linuxPackages-cachyos-bore-lto" else "linuxPackages-cachyos-server";

        cachyName = base + suffix;
        cachyKernel = pkgs.cachyosKernels.${cachyName} or null;

        kernelBase = if host == "desktop" then "linux-cachyos-bore-lto" else "linux-cachyos-server";
        kernelName = kernelBase + suffix;
        kernelDrv = pkgs.cachyosKernels.${kernelName} or null;

        # ── Pinned version ───────────────────────────────────────────────────
        # false → use whatever version the flake currently provides
        # true  → pin to a specific kernel version via pname/version/src
        # Note: usePinnedKernel and useCustomKernel can be combined;
        #       pinnedKernelArgs is merged into customKernelArgs if both are true
        usePinnedKernel = false;
        pinnedKernelArgs = {
          pname = "linux-cachyos-pinned";
          version = "6.12.34";
          src = pkgs.fetchurl {
            url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.34.tar.xz";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };
        };
        # ────────────────────────────────────────────────────────────────────

        # ── Custom kernel ────────────────────────────────────────────────────
        # false → unmodified CachyOS kernel, binary cache intact
        # true  → override with customKernelArgs below, builds from source
        useCustomKernel = false;
        customKernelArgs = {
          # Compiler & Optimization
          #lto = "thin"; # "none" | "thin" | "full"
          #processorOpt = "x86_64-v3"; # "x86_64-v1" | "x86_64-v2" | "x86_64-v3" | "x86_64-v4" | "zen4" | "native"
          #autofdo = false; # false | true | ./path/to/profile

          # CachyOS Fine Tuning
          #cpusched = "bore"; # "eevdf" | "bore" | "bmq" | "rt" | "rt-bore" | null
          #hzTicks = "1000"; # "250" | "300" | "500" | "750" | "1000" | null
          #tickrate = "full"; # "full" | "periodic" | "idle" | "nohz_full" | null
          #preemptType = "full"; # "full" | "voluntary" | "none" | null
          #performanceGovernor = false;
          #ccHarder = true;
          #bbr3 = false;
          #hugepage = "always"; # "always" | "madvise" | "never" | null
          #kcfi = false;

          # Additional Patches
          #hardened = false;
          #rt = false;
          #acpiCall = false;
          #handheld = false;

          # Extra patches
          patches = [ ];
          prePatch = "";
          postPatch = "";
        };
        # ────────────────────────────────────────────────────────────────────

        # Merge pinnedKernelArgs into overrideArgs if both switches are active,
        # pinned args (pname/version/src) always take precedence
        overrideArgs =
          if usePinnedKernel && useCustomKernel then
            customKernelArgs // pinnedKernelArgs
          else if usePinnedKernel then
            pinnedKernelArgs
          else
            customKernelArgs;
      in
      if isArm then
        # no CachyOS on ARM → use stock NixOS kernel
        pkgs.linuxPackages_latest
      else if host == "server" && arch != "x86-64-v1" then
        # explicit guard: server kernel exists only as v1
        throw "kernelPackages: CachyOS server kernel only provides x86-64-v1, got ${arch}"
      else if useCustomKernel || usePinnedKernel then
        if kernelDrv != null then
          helpers.kernelModuleLLVMOverride (pkgs.linuxKernel.packagesFor (kernelDrv.override overrideArgs))
        else
          throw "kernelPackages: ${kernelName} not found for ${arch}"
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

  ### Add substituer from CachyOS 3rd part source (binary)
  nix.settings = {
    extra-substituters = [
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };
}
