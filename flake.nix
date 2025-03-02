### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
    nur.url = "github:nix-community/nur";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-23-11, home-manager, nur, ... }@inputs:
  let
    ### System variable
    lib = nixpkgs.lib;
    pkgs = nixpkgs.legacyPackages.${system};
    system = "x86_64-linux";
    
    ### Other sources
    pkgsExtra = {
      pkgs-23-11 = nixpkgs-23-11.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    };
  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        inherit system;
        ### Use NUR as a settings
        specialArgs = { 
          inherit nur pkgsExtra;
        };
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-probook-profile.nix
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit nur pkgsExtra; };
          }
        ];
      };
      
      hp-240 = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-240-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit nur pkgsExtra; };
          }
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
      
      vm-desktop-efi = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-efi-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/desktop-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit nur pkgsExtra; };
          }
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
      
      vm-desktop-bios = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-bios-novio-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/server-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit nur pkgsExtra; };
          }
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
      
      vm-desktop-bios-virtio = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-bios-vio-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./hm-profiles/server-profile.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit nur pkgsExtra; };
          }
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
      
      vm-no-gui-efi = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-efi-profile.nix
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
      
      vm-no-gui-bios = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-bios-novio-profile.nix
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
      
      vm-no-gui-bios-virtio = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nur pkgsExtra; };
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-bios-vio-profile.nix
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; })
        ];
      };
    };
  };
}
