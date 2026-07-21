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
  homeManagerConfig,
  rev,
  branch,
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
      homeManagerConfig
      rev
      branch
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
  };

  # VM preset (CLI bios)
  vm-no-gui-bios = mkMachine {
    hostname = "nixos-kvm-srv-bios";
    profile = ./profiles/vm-no-gui-bios-novio-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
  };

  # VM preset (CLI bios (no virtio disk))
  vm-no-gui-bios-virtio = mkMachine {
    hostname = "nixos-kvm-desktop-bios-virtio";
    profile = ./profiles/vm-no-gui-bios-vio-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
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
  };

  ### --- ISO Images ---

  iso-gnome = helpers.iso.mkIso {
    edition = "GNOME";
    profile = ./iso/gnome.nix;
    hostname = "nixos-iso";
    extraModules = [ ./configurations/hardware-configuration/specific/nvidia.nix ];
    hmFeatures = [ "cli" "shell" "desktop-core" "gnome" ];
    keyboardSession = true;
  };

  iso-minimal = helpers.iso.mkIso {
    edition = "CLI";
    profile = ./iso/cli.nix;
    hostname = "nixos-iso-minimal";
    hmFeatures = [ ];
  };
}
