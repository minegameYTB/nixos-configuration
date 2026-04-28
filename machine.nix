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

{
  ### Theses entry is imported by nixosConfiguration (when i split flake.nix)

  # HP-probook
  hp-probook = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/hp-probook-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "HP-probook"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerDesktopConfig defaultArch)
    ];
  };

  # HP-240
  hp-240 = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/hp-240-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "UTILISA-0SK6G4E"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerDesktopConfig defaultArch)
    ];
  };

  # VM preset (desktop efi)
  vm-desktop-efi = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/vm-desktop-efi-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "nixos-kvm-desktop"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerDesktopConfig defaultArch)
    ];
  };

  # VM preset (desktop bios)
  vm-desktop-bios = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/vm-desktop-bios-novio-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "nixos-kvm-desktop-bios"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerDesktopConfig defaultArch)
    ];
  };

  # VM preset (desktop bios (no virtio disk))
  vm-desktop-bios-virtio = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/vm-desktop-bios-vio-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "nixos-kvm-desktop-bios-virtio"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerDesktopConfig defaultArch)
    ];
  };

  # VM preset (CLI efi)
  vm-no-gui-efi = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/vm-no-gui-efi-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "nixos-kvm-srv"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerServerConfig defaultArch)

      ### Add wrapper expression module
      (import ./profiles/base-profiles/vm-no-gui-wrapped.nix {
        extraModules = [
          #./configurations/configs/specific/vm/guest/nextcloud.nix
        ];
      })
    ];
  };

  # VM preset (CLI bios)
  vm-no-gui-bios = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/vm-no-gui-bios-novio-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "nixos-kvm-srv-bios"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerServerConfig defaultArch)
    ];
  };

  # VM preset (CLI bios (no virtio disk))
  vm-no-gui-bios-virtio = lib.nixosSystem {
    system = defaultArch;
    ### Inject pkgs attr with options
    pkgs = pkgsFor defaultArch;
    specialArgs = specialArgs defaultArch;
    modules = [
      ./configurations/configuration.nix
      ./profiles/vm-no-gui-bios-vio-profile.nix

      ### Import fs configuration
      ./configurations/hardware-configuration/filesystem/btrfs

      ### Global overlay settings
      (overlay defaultArch)

      ### Hostname config
      { networking.hostName = "nixos-kvm-desktop-bios-virtio"; }

      ### Home-manager module
      home-manager.nixosModules.home-manager
      (homeManagerServerConfig defaultArch)
    ];
  };

}
