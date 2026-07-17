{
  lib,
  overlay,
  home-manager,
  defaultArch ? "x86_64-linux",
  pkgsFor,
  pkgsPatched,
  specialArgs,
  homeManagerDesktopConfig,
  homeManagerServerConfig,
  ...
}:

let
  ### ---------------------------------------------------------------------------
  ### mkMachine: Helper to create a NixOS system configuration.
  ###
  ###   hostname        : (required) networking.hostName value
  ###   profile         : (required) path to the machine-specific profile (./profiles/...)
  ###   fs              : (required) path to the filesystem config (./configurations/hardware-configuration/filesystem/...)
  ###   homeManagerType : "desktop" (default) or "server" — selects the home-manager submodule
  ###   arch            : target architecture (default: defaultArch = "x86_64-linux")
  ###   usePatched      : if true, use pkgsPatched (with custom nixpkgs patches) instead of pkgsFor
  ###   extraModules    : list of additional NixOS modules to inject
  ###
  ### Available filesystem configs:
  ###   ./configurations/hardware-configuration/filesystem/btrfs              — EFI/BIOS btrfs
  ###   ./configurations/hardware-configuration/filesystem/luks-btrfs         — EFI LUKS + btrfs
  ###   ./configurations/hardware-configuration/filesystem/zfs                — EFI ZFS (zroot)
  ###
  ### Install with: sudo ./install.sh  (prompts for filesystem choice)
  ###
  ### Examples:
  ###   Standard desktop (btrfs):
  ###     mkMachine {
  ###       hostname = "my-machine";
  ###       profile  = ./profiles/my-profile.nix;
  ###       fs       = ./configurations/hardware-configuration/filesystem/btrfs;
  ###     }
  ###
  ###   Server on aarch64 with a custom nixpkgs patch:
  ###     mkMachine {
  ###       hostname    = "rpi-server";
  ###       profile     = ./profiles/rpi-profile.nix;
  ###       fs          = ./configurations/hardware-configuration/filesystem/btrfs;
  ###       arch        = "aarch64-linux";
  ###       homeManagerType = "server";
  ###       usePatched  = true;
  ###     }
  ### ---------------------------------------------------------------------------
  mkMachine =
    {
      hostname,
      profile,
      fs,
      homeManagerType ? "desktop",
      extraModules ? [ ],
      arch ? defaultArch,
      usePatched ? false,
    }:
    let
      ### Select pkgs set (optionally use patched nixpkgs for testing PRs/patches)
      machinePkgs = if usePatched then pkgsPatched arch else pkgsFor arch;
      ### Select home-manager config based on machine type (desktop or server)
      hmConfig =
        if homeManagerType == "server" then homeManagerServerConfig else homeManagerDesktopConfig;
    in
    lib.nixosSystem {
      system = arch;
      pkgs = machinePkgs;
      specialArgs = specialArgs arch;
      modules = [
        ../configurations/configuration.nix

        profile
        fs

        (overlay arch)

        { networking.hostName = hostname; }

        home-manager.nixosModules.home-manager
        (hmConfig arch)
      ]
      ++ extraModules;
    };
in
{
  inherit mkMachine;
}
