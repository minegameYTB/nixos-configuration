### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    ### Main repo
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    
    ### To test a PR on a flake :
    ### github:username/repo?ref=pull/<PR number>/head
    
    ### Other repos
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix/release-25.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak/latest";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### Rice/customization
    catppuccin-wallpapers = {
      url = "github:zhichaoh/catppuccin-wallpapers";
      flake = false;
    };
    dotfiles-minegameYTB = {
      url = "github:minegameYTB/dotfiles";
      flake = false;
    };

    ### Other nixpkgs repos
    nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-24-11.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  
    ### Utilities
    ### Import blocklist as non flake to import list directly on /etc/hosts (abstraction layer with nix)
    blocklist = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };
  };
  
  outputs = { 
    self,
    nixpkgs,
    stylix,
    nixpkgs-unstable,
    nixpkgs-24-11,
    nixpkgs-23-11,
    home-manager,
    zen-browser,
    nur,
    nix-flatpak,
    ...
  }@inputs:
  
  let
    ### System variables
    lib = nixpkgs.lib;
    systems = [ "x86_64-linux" "aarch64-linux" ];
    users = [ "minegame" ];

    ### Nur overlay variable
    nurOverlay = ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; });

    ### Other sources (pkgs set)
    pkgsExtra = system: {
      pkgs-23-11 = nixpkgs-23-11.legacyPackages.${system};
      pkgs-24-11 = nixpkgs-24-11.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    };

    ### specialArgs
    specialArgs = system: {
      inherit inputs;
      pkgsExtra = pkgsExtra system;
      inherit (inputs) nur;
      inherit (inputs) zen-browser;
    };

    ### Home-manager desktop config module (not a function call)
    homeManagerDesktopConfig = { config, pkgs, ... }: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      
      ### Import users as a function
      home-manager.users = lib.genAttrs users (username:
        import ./hm-profiles/desktop-profile-wrapped.nix {
          inherit username;
          extraModules = [
            ./home-manager/configs/specific/nixos/stylix.nix
          ];
        }
      );
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = specialArgs "x86_64-linux";
    };

    ### Home-manager server config module (not a function call)
    homeManagerServerConfig = { config, pkgs, ... }: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users = lib.genAttrs users (username:
        import ./hm-profiles/server-profile.nix { inherit username; }
      );
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = specialArgs "x86_64-linux";
    };

    ### Create a function named "mkHome" that takes system and username
    mkHome = system: username: home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { 
        inherit system;
        ### Allow non-free software in standalone home-manager conf
        config = { allowUnfree = true; };
      };
      modules = [
        ({ config, pkgs, ... }: 
          { 
            nixpkgs.overlays = [ nur.overlays.default ]; 
            ### Specific aliases for home-manager standalone
            home.shellAliases = {
            
              ### Override nix.conf settings on nix standalone configuration
              nix = "nix --refresh -v --cores 2";
              
              ### home-manager alias
              home-manager = "home-manager -b bak";
              
              ### ls and cat aliases
              ls = "${pkgs.lsd}/bin/lsd";
              cat = "${pkgs.bat}/bin/bat";
              
              ### expose legacy ls and cat as an alias
              "ls.ori" = "${pkgs.coreutils}/bin/ls";
              "cat.ori" = "${pkgs.coreutils}/bin/cat";
            };
          }
        )
        ### import desktop profile with a setting (username)
        (import ./hm-profiles/desktop-profile.nix { inherit username; })
        ### add stylix module
        stylix.homeModules.stylix
      ];
      extraSpecialArgs = {
        ### Export "inputs" "nur" "inputs.zen-browser" and "pkgsExtra" to home-manager configuration
        inherit inputs nur;
        pkgsExtra = pkgsExtra system;
        inherit (inputs) zen-browser;
      };
    };

  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-probook-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "HP-probook"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerDesktopConfig
        ];
      };
      hp-240 = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-240-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "UTILISA-0SK6G4E"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerDesktopConfig
        ];
      };
      vm-desktop-efi = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-efi-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "nixos-pve-desktop"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerDesktopConfig
        ];
      };
      vm-desktop-bios = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-bios-novio-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "nixos-pve-desktop-bios"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerDesktopConfig
        ];
      };
      vm-desktop-bios-virtio = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-bios-vio-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "nixos-pve-desktop-bios-virtio"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerDesktopConfig
        ];
      };
      vm-no-gui-efi = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-efi-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "nixos-pve-srv"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerServerConfig

          ### Add wrapper expression module
          (import ./profiles/base-profiles/vm-no-gui-wrapped.nix {
            extraModules = [
              ./configurations/configs/specific/vm/guest/nextcloud.nix
            ];
          })
        ];
      };
      vm-no-gui-bios = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-bios-novio-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "nixos-pve-srv-bios"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerServerConfig
        ];
      };
      vm-no-gui-bios-virtio = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = specialArgs "x86_64-linux";
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-bios-vio-profile.nix
          
          ### Nur overlay
          nurOverlay
          
          ### Hostname config
          { networking.hostName = "nixos-pve-desktop-bios-virtio"; }
          
          ### Home-manager module
          home-manager.nixosModules.home-manager
          homeManagerServerConfig
        ];
      };
    };

    ### Multi-architecture home-manager configurations
    homeConfigurations = lib.listToAttrs (
      lib.concatMap (username:
        lib.concatMap (system:
          [{
            name = "${username}@${system}";
            value = mkHome system username;
          }]
        ) systems
      ) users
    );
  };
}
