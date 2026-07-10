{
  ### Include all declared attribute from flake.nix
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
  helpers = import ./lib/default.nix {
    inherit
      lib
      overlay
      home-manager
      inputs
      defaultArch
      pkgsFor
      pkgsPatched
      specialArgs
      homeManagerDesktopConfig
      homeManagerServerConfig
      ;
  };

  inherit (helpers.machine) mkMachine;

in
{
  ### --- Physical machines ---

  # HP-probook
  hp-probook = mkMachine {
    hostname = "HP-probook";
    profile = ./profiles/hp-probook-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/zfs;
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

  ### --- Test VMs ---

  # VM preset (desktop efi LUKS btrfs)
  vm-desktop-efi-luks = mkMachine {
    hostname = "nixos-kvm-desktop";
    profile = ./profiles/vm-desktop-efi-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/luks-btrfs/vm.nix;
  };

  # VM preset (desktop efi ZFS) — requires at least 16 GiB RAM (8 GiB bare minimum, tight during nixos-rebuild)
  vm-desktop-efi-zfs = mkMachine {
    hostname = "nixos-kvm-desktop-zfs";
    profile = ./profiles/vm-desktop-efi-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/zfs;
  };

  ### --- Headless / server VMs (ZFS) ---

  # VM preset (CLI efi ZFS)
  vm-no-gui-efi-zfs = mkMachine {
    hostname = "nixos-kvm-srv-zfs";
    profile = ./profiles/vm-no-gui-efi-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/zfs;
    homeManagerType = "server";
  };

  ### --- ISO Images ---

  # ISO with GNOME desktop and Home Manager
  iso-gnome = let
    i = helpers.iso;
    isoSpecialArgs = i.isoSpecialArgs i.isoArch // {
      inherit (i) mkKeyboardSpec keyboardSetupScript keyboardSessionScript;
    };
  in lib.nixosSystem {
    system = i.isoArch;
    pkgs = pkgsFor i.isoArch;
    specialArgs = isoSpecialArgs;
    modules = [
      ./profiles/iso-profile.nix

      (overlay i.isoArch)

      { networking.hostName = "nixos-iso"; }

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.nixos = import ./hm-profiles/desktop-profile-wrapped.nix {
            username = "nixos";
            extraModules = [ ./home-manager/configs/specific/nixos ];
          };
          extraSpecialArgs = isoSpecialArgs;
        };
      }

      i.isoModule
    ];
  };

  # ISO minimal (CLI, no GUI) with Home Manager
  iso-minimal = let
    i = helpers.iso;
    isoSpecialArgs = i.isoSpecialArgs i.isoArch // {
      inherit (i) mkKeyboardSpec keyboardSetupScript;
    };
  in lib.nixosSystem {
    system = i.isoArch;
    pkgs = pkgsFor i.isoArch;
    specialArgs = isoSpecialArgs;
    modules = [
      ./profiles/iso-minimal-profile.nix

      (overlay i.isoArch)

      { networking.hostName = "nixos-iso-minimal"; }

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.nixos = import ./hm-profiles/server-profile.nix {
            username = "nixos";
          };
          extraSpecialArgs = isoSpecialArgs;
        };
      }

      i.isoModule
    ];
  };
}
