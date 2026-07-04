{
  ### Include all declared attribute from flake.nix (pkgs* variable is controlled by flake.nix, default arch is "x86_64-linux", precise arch to override default settings)
  lib,
  overlay,
  home-manager,
  inputs,
  defaultArch ? "x86_64-linux",

  ### Function from flake.nix imported here by imported function in nix
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
  ### Examples:
  ###   Standard desktop machine:
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
    { hostname, profile, fs, homeManagerType ? "desktop", extraModules ? [ ], arch ? defaultArch, usePatched ? false }:
    let
      ### Select pkgs set (optionally use patched nixpkgs for testing PRs/patches)
      machinePkgs = if usePatched then pkgsPatched arch else pkgsFor arch;
      ### Select home-manager config based on machine type (desktop or server)
      hmConfig = if homeManagerType == "server" then homeManagerServerConfig else homeManagerDesktopConfig;
    in
    lib.nixosSystem {
      system = arch;
      pkgs = machinePkgs;
      specialArgs = specialArgs arch;
      modules =
        [
          ./configurations/configuration.nix

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
  ### --- Physical machines ---

  # HP-probook
  hp-probook = mkMachine {
    hostname = "HP-probook";
    profile = ./profiles/hp-probook-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/luks-btrfs;
  };

  # HP-240
  hp-240 = mkMachine {
    hostname = "UTILISA-0SK6G4E";
    profile = ./profiles/hp-240-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
  };

  ### --- Desktop VMs (EFI) ---

  # VM preset (desktop efi)
  vm-desktop-efi = mkMachine {
    hostname = "nixos-kvm-desktop";
    profile = ./profiles/vm-desktop-efi-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
  };

  # VM preset (desktop efi) (LUKS encrypted)
  vm-desktop-efi-luks = mkMachine {
    hostname = "nixos-kvm-desktop";
    profile = ./profiles/vm-desktop-efi-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/luks-btrfs/vm.nix;
  };

  ### --- Desktop VMs (BIOS) ---

  # VM preset (desktop bios)
  vm-desktop-bios = mkMachine {
    hostname = "nixos-kvm-desktop-bios";
    profile = ./profiles/vm-desktop-bios-novio-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
  };

  # VM preset (desktop bios (no virtio disk))
  vm-desktop-bios-virtio = mkMachine {
    hostname = "nixos-kvm-desktop-bios-virtio";
    profile = ./profiles/vm-desktop-bios-vio-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
  };

  ### --- Headless / server VMs ---

  # VM preset (CLI efi)
  vm-no-gui-efi = mkMachine {
    hostname = "nixos-kvm-srv";
    profile = ./profiles/vm-no-gui-efi-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
    homeManagerType = "server";
    ### Add wrapper expression module
    extraModules = [
      (import ./profiles/base-profiles/vm-no-gui-wrapped.nix {
        extraModules = [
          #./configurations/configs/specific/vm/guest/nextcloud.nix
        ];
      })
    ];
  };

  # VM preset (CLI bios)
  vm-no-gui-bios = mkMachine {
    hostname = "nixos-kvm-srv-bios";
    profile = ./profiles/vm-no-gui-bios-novio-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
    homeManagerType = "server";
  };

  # VM preset (CLI bios (no virtio disk))
  vm-no-gui-bios-virtio = mkMachine {
    hostname = "nixos-kvm-desktop-bios-virtio";
    profile = ./profiles/vm-no-gui-bios-vio-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
    homeManagerType = "server";
  };
}
