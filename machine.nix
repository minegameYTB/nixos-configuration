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
    if type == "desktop" then ./profiles/vm-desktop-profile.nix else ./profiles/vm-cli-profile.nix;

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

  ### Per-machine auto-update wiring (feat/auto-update, see doc/auto-update.md).
  ### Centralized here: one line per machine, configuration passed explicitly.
  ### Defaults apply (daily checks, no auto-reboot): the machines follow the
  ### soaked buffer channel and stage new generations, activation stays manual.
  autoUpdate = configuration: {
    system.autoUpdate = {
      enable = true;
      inherit configuration;
    };
  };

in
{
  ### --- Physical machines ---

  # HP-probook
  hp-probook = mkMachine {
    hostname = "HP-probook";
    profile = ./profiles/hp-probook-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/zfs;
    extraModules = [ ];
    usePatched = false;
  };

  # HP-240
  hp-240 = mkMachine {
    hostname = "UTILISA-0SK6G4E";
    profile = ./profiles/hp-240-profile.nix;
    fs = ./configurations/hardware-configuration/filesystem/btrfs;
    extraModules = [
      ### Auto-update enabled (see doc/auto-update.md)
      (autoUpdate "hp-240")
    ];
    usePatched = false;
  };

  ### --- Desktop VMs ---

  # VM preset (desktop efi)
  vm-desktop-efi = mkMachine {
    hostname = "nixos-kvm-desktop";
    profile = base "desktop";
    fs = fs "btrfs";
    extraModules = [
      boot.efi
      ### Auto-update enabled (see doc/auto-update.md)
      (autoUpdate "vm-desktop-efi")
    ];
    withHomeManager = true;
    usePatched = false;
  };

  # VM preset (desktop bios)
  vm-desktop-bios = mkMachine {
    hostname = "nixos-kvm-desktop-bios";
    profile = base "desktop";
    fs = fs "btrfs";
    extraModules = [ boot.bios-nv ];
    usePatched = false;
  };

  # VM preset (desktop bios virtio)
  vm-desktop-bios-virtio = mkMachine {
    hostname = "nixos-kvm-desktop-bios-virtio";
    profile = base "desktop";
    fs = fs "btrfs";
    extraModules = [ boot.bios-vio ];
    usePatched = false;
  };

  ### --- Headless / server VMs ---

  # VM preset (CLI efi)
  vm-cli-efi = mkMachine {
    hostname = "nixos-kvm-srv";
    profile = base "cli";
    fs = fs "btrfs";
    extraModules = [
      boot.efi
      ### Auto-update enabled (see doc/auto-update.md)
      (autoUpdate "vm-cli-efi")
    ];
    userOverrides = cliOverrides;
    withHomeManager = true;
    usePatched = false;
  };

  # VM preset (CLI bios)
  vm-cli-bios = mkMachine {
    hostname = "nixos-kvm-srv-bios";
    profile = base "cli";
    fs = fs "btrfs";
    extraModules = [ boot.bios-nv ];
    userOverrides = cliOverrides;
    usePatched = false;
  };

  # VM preset (CLI bios virtio)
  vm-cli-bios-virtio = mkMachine {
    hostname = "nixos-kvm-srv-bios-virtio";
    profile = base "cli";
    fs = fs "btrfs";
    extraModules = [ boot.bios-vio ];
    userOverrides = cliOverrides;
    usePatched = false;
  };

  ### --- Test VMs ---

  # VM preset (desktop efi LUKS btrfs)
  vm-desktop-efi-luks = mkMachine {
    hostname = "nixos-kvm-desktop-luks";
    profile = base "desktop";
    fs = fs "luks";
    extraModules = [ boot.efi ];
    usePatched = false;
  };

  # VM preset (desktop efi ZFS) — requires at least 16 GiB RAM
  vm-desktop-efi-zfs = mkMachine {
    hostname = "nixos-kvm-desktop-zfs";
    profile = base "desktop";
    fs = fs "zfs";
    extraModules = [
      boot.efi
      (autoUpdate "vm-desktop-efi-zfs")
    ];
    usePatched = false;
  };

  # VM preset (CLI efi ZFS)
  vm-cli-efi-zfs = mkMachine {
    hostname = "nixos-kvm-srv-zfs";
    profile = base "cli";
    fs = fs "zfs";
    extraModules = [ boot.efi ];
    userOverrides = cliOverrides;
    usePatched = false;
  };

  ### --- CI VMs (vanilla kernel, no CachyOS — fast for GHA) ---

  ci-efi = mkMachine {
    hostname = "nixos-ci-efi";
    profile = ./profiles/ci-profile.nix;
    fs = fs "btrfs";
    extraModules = [ boot.efi ];
    userOverrides = cliOverrides;
    withHomeManager = true;
    usePatched = false;
  };

  ci-bios = mkMachine {
    hostname = "nixos-ci-bios";
    profile = ./profiles/ci-profile.nix;
    fs = fs "btrfs";
    extraModules = [ boot.bios-nv ];
    userOverrides = cliOverrides;
    withHomeManager = true;
    usePatched = false;
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
