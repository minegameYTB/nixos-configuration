### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    ### Main repo
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    
    ### To test a PR on a flake : 
    ### github:username/repo?ref=pull/<PR number>/head
    
    ### Other repos
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix/release-24.11";
    
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
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
  };
  outputs = { self, nixpkgs, stylix, nixpkgs-unstable, nixpkgs-23-11, home-manager, zen-browser, nur, ... }@inputs:
  let
    ### System variable
    lib = nixpkgs.lib;
    pkgs = nixpkgs.legacyPackages.${system};
    system = "x86_64-linux";
    
    ### Home manager variable
    users = [ "minegame" ];
    
    ### Create a function named "mkHome" and add the sub function named username (username: ...)
    mkHome = username: home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { 
        inherit system;
        
        ### Allow non free software to home-manager standalone conf
        config = { allowUnfree = true; };
      };
      modules = [
        ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        (import ./hm-profiles/desktop-profile.nix { inherit username; })
      ];
      extraSpecialArgs = {
        ### Export "inputs" "nur" "inputs.zen-browser" and "pkgsExtra" to home-manager configuration
        inherit inputs nur pkgsExtra;
        inherit (inputs) zen-browser;
      };
    };

    ### Other sources
    pkgsExtra = {
      pkgs-23-11 = nixpkgs-23-11.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    };

  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        inherit system;
        ### Use NUR as a settings, zen-browser flake is import as "inputs"
        specialArgs = { 
          inherit pkgsExtra inputs;
          inherit (inputs) nur;
          inherit (inputs) zen-browser;
        };
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-probook-profile.nix
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users = lib.genAttrs users (username:
              import ./hm-profiles/desktop-profile.nix { inherit username; }
            );
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { 
              inherit inputs nur pkgsExtra; 
              inherit (inputs) zen-browser;
            };
          }
        ];
      };
      
      hp-240 = lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit pkgsExtra;
          inherit (inputs) nur;
          inherit (inputs) zen-browser;
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/hp-240-profile.nix
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { 
              inherit inputs nur pkgsExtra;
              inherit (inputs) zen-browser;
            };
          }
        ];
      };
      
      vm-desktop-efi = lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgsExtra;
          inherit (inputs) nur;
          inherit (inputs) zen-browser;
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/vm-desktop-efi-profile.nix
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { 
              inherit inputs nur pkgsExtra;
              inherit (inputs) zen-browser;
            };
          }
        ];
      };
      
      vm-desktop-bios = lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit pkgsExtra;
          inherit (inputs) nur;
          inherit (inputs) zen-browser;
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/vm-desktop-bios-novio-profile.nix
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { 
              inherit inputs nur pkgsExtra;
              inherit (inputs) zen-browser;
            };
          }
        ];
      };
      
      vm-desktop-bios-virtio = lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgsExtra;
          inherit (inputs) nur;
          inherit (inputs) zen-browser;
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/vm-desktop-bios-vio-profile.nix
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { 
              inherit inputs nur pkgsExtra;
              inherit (inputs) zen-browser;
            };
          }
        ];
      };
      
      vm-no-gui-efi = lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit nur pkgsExtra;
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-efi-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            ### Import users as a function (using "{ inherit username } (with "(username: ...):")")
            home-manager.users = lib.genAttrs users (username:
              import ./hm-profiles/server-profile.nix { inherit username; }
            );
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = {
              inherit inputs nur pkgsExtra;
              inherit (inputs) zen-browser;
            };
          }
        ];
      };
      
      vm-no-gui-bios = lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit nur pkgsExtra;
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-bios-novio-profile.nix
        ];
      };
      
      vm-no-gui-bios-virtio = lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit nur pkgsExtra; 
        };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-bios-vio-profile.nix
        ];
      };
    };
    ### Use dynamic attribute to use home-manager standalone (need testing)
    homeConfigurations = lib.genAttrs users mkHome;
  };
}
