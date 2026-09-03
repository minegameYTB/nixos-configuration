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

  cliOverrides = {
    global = {
      without = [ "desktop-core" ];
    };
    minegame = {
      without = [
        "gnome"
        "games"
        "browser"
        "multimedia"
        "customization"
      ];
    };
  };

  base =
    type:
    if type == "desktop" then
      ./profiles/base-profiles/vm-desktop-profile.nix
    else
      ./profiles/base-profiles/vm-cli-profile.nix;

  fs =
    type:
    if type == "luks" then
      ./configurations/hardware-configuration/filesystem/luks-btrfs/vm.nix
    else if type == "zfs" then
      ./configurations/hardware-configuration/filesystem/zfs
    else
      ./configurations/hardware-configuration/filesystem/btrfs;

  boot = {
    efi = ./configurations/configs/bootloader/systemd-boot.nix;
    bios-nv = ./configurations/configs/bootloader/grub2-specific/bios-novirtio.nix;
    bios-vio = ./configurations/configs/bootloader/grub2-specific/bios-virtio.nix;
  };

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

  ### --- Desktop VMs ---

  # VM preset (desktop efi)
  vm-desktop-efi = mkMachine {
    hostname = "nixos-kvm-desktop";
    profile = base "desktop";
    fs = fs "btrfs";
    extraModules = [ boot.efi ];
    withHomeManager = true;
  };

  # VM preset (desktop bios)
  vm-desktop-bios = mkMachine {
    hostname = "nixos-kvm-desktop-bios";
    profile = base "desktop";
    fs = fs "btrfs";
    extraModules = [ boot.bios-nv ];
  };

  # VM preset (desktop bios virtio)
  vm-desktop-bios-virtio = mkMachine {
    hostname = "nixos-kvm-desktop-bios-virtio";
    profile = base "desktop";
    fs = fs "btrfs";
    extraModules = [ boot.bios-vio ];
  };

  ### --- Headless / server VMs ---

  # VM preset (CLI efi)
  vm-cli-efi = mkMachine {
    hostname = "nixos-kvm-srv";
    profile = base "cli";
    fs = fs "btrfs";
    extraModules = [ boot.efi ];
    userOverrides = cliOverrides;
    withHomeManager = true;
  };

  # VM preset (CLI bios)
  vm-cli-bios = mkMachine {
    hostname = "nixos-kvm-srv-bios";
    profile = base "cli";
    fs = fs "btrfs";
    extraModules = [ boot.bios-nv ];
    userOverrides = cliOverrides;
  };

  # VM preset (CLI bios virtio)
  vm-cli-bios-virtio = mkMachine {
    hostname = "nixos-kvm-srv-bios-virtio";
    profile = base "cli";
    fs = fs "btrfs";
    extraModules = [ boot.bios-vio ];
    userOverrides = cliOverrides;
  };

  ### --- Test VMs ---

  # VM preset (desktop efi LUKS btrfs)
  vm-desktop-efi-luks = mkMachine {
    hostname = "nixos-kvm-desktop-luks";
    profile = base "desktop";
    fs = fs "luks";
    extraModules = [ boot.efi ];
  };

  # VM preset (desktop efi ZFS) — requires at least 16 GiB RAM
  vm-desktop-efi-zfs = mkMachine {
    hostname = "nixos-kvm-desktop-zfs";
    profile = base "desktop";
    fs = fs "zfs";
    extraModules = [ boot.efi ];
  };

  # VM preset (CLI efi ZFS)
  vm-cli-efi-zfs = mkMachine {
    hostname = "nixos-kvm-srv-zfs";
    profile = base "cli";
    fs = fs "zfs";
    extraModules = [ boot.efi ];
    userOverrides = cliOverrides;
  };

  ### --- ISO Images ---

  iso-gnome = helpers.iso.mkIso {
    edition = "GNOME";
    profile = ./iso/gnome.nix;
    hostname = "nixos-iso";
    extraHomeModules = [
      ./hm-profiles/users/minegame/apps.nix
    ];
    hmFeatures = [
      "cli"
      "shell"
      "shell-no-zsh-hm"
      "desktop-core"
      "gnome"
      "browser"
    ];
    keyboardSession = true;
    withHomeManager = true;
  };

  iso-minimal = helpers.iso.mkIso {
    edition = "CLI";
    profile = ./iso/cli.nix;
    hostname = "nixos-iso-minimal";
    hmFeatures = [
      "cli"
      "shell"
      "shell-no-zsh-hm"
    ];
    withHomeManager = true;
  };
}
