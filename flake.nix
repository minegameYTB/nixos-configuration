### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
 description = "A flake with my configuration";

 inputs = {
   ### Main repo
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

   ### To test a PR on a flake:
   ### github:username/repo?ref=pull/<PR number>/head

   ### Other nixpkgs repos
   nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
   nixpkgs-24-11.url = "github:NixOS/nixpkgs/nixos-24.11";
   nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

   ### Temporairy use PR for deezer-enhanced
   nixpkgs-pr.url = "github:NixOS/nixpkgs?ref=pull/424686/head";

   ### Other repos
   home-manager = {
     url = "github:nix-community/home-manager/release-25.05";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   zen-browser.url = "github:0xc000022070/zen-browser-flake/";
   nur = {
     url = "github:nix-community/nur";
     inputs.nixpkgs.follows = "nixpkgs-unstable";
   };
   stylix.url = "github:danth/stylix/release-25.05";
   nix-flatpak.url = "github:gmodena/nix-flatpak/latest";
   nix-index-database = {
     url = "github:nix-community/nix-index-database";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   #nurpkgs-repo-minegameYTB.url = "github:minegameYTB/nurpkgs-repo";
   ghostty.url = "github:ghostty-org/ghostty/5306e7cf567ccb37028701a00504bcf28484b155";

   ### Rice/customization
   catppuccin-wallpapers = {
     url = "github:zhichaoh/catppuccin-wallpapers";
     flake = false;
   };  
   dotfiles-minegameYTB = {
     url = "github:minegameYTB/dotfiles";
     flake = false;
   };

   ### Utilities
   ### Import blocklist as non-flake for /etc/hosts
   blocklist = {
     url = "github:StevenBlack/hosts";
     flake = false;
   };
   lanzaboote = {
     url = "github:nix-community/lanzaboote/v0.4.2";
     inputs.nixpkgs.follows = "nixpkgs";
   };
 };

 outputs = {
   self,
   nixpkgs,
   stylix,
   nixpkgs-unstable,
   nixpkgs-24-11,
   nixpkgs-23-11,
   nixpkgs-pr,
   home-manager,
   zen-browser,
   nur,
   nix-flatpak,
   ghostty,
   #nurpkgs-repo-minegameYTB,
   lanzaboote,
   ...
 }@inputs:

 let
   ### System variables
   ### Nixpkgs config (unfree allowed)
   nixpkgsConfig = {
     allowUnfree = true;
   };  
   lib = nixpkgs.lib;

   ### Supported systems (x86_64 + ARM)
   systems = [ "x86_64-linux" "aarch64-linux" ];
   users = [ "minegame" ];

   ### Create patched nixpkgs for each system
   nixpkgs-patched = system: (import nixpkgs { inherit system; }).applyPatches {
     #name = "nixpkgs-patched-421549";
     src = nixpkgs;
     patches = [
       #(builtins.fetchurl {
       #  ### Add ".patch" to get this link for a PR
       #  url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/421549.patch";
       #  sha256 = "1m0s79pa9kq2awd3rykn0w8b6qryzf18ddjld4im0gv6jj0y9qbn";
       #})

       ### Local patch
       #./configurations/patch/nixpkgs/0000-qemu-fix-version.patch
       #./configurations/patch/nixpkgs/0000-libvirt-update.patch
     ];
   };

   ### Import patched nixpkgs into pkgs-patched attr
   pkgsPatched = system: import (nixpkgs-patched system) {
     inherit system;
     config = nixpkgsConfig;
   };

   ### Set unfree package directly from standard pkgs (non-patched) attr
   pkgsFor = system: import nixpkgs {
     inherit system;
     config = nixpkgsConfig;
   };

   ### Nur overlay
   nurOverlay = ({ config, pkgs, ... }: { nixpkgs.overlays = [ nur.overlays.default ]; });

   ### Other sources (pkgs set)
   pkgsExtra = system: {
     pkgs-23-11 = import nixpkgs-23-11 {
       inherit system;
       config = nixpkgsConfig;
     };
     pkgs-24-11 = import nixpkgs-24-11 {
       inherit system;
       config = nixpkgsConfig;
     };
     pkgs-unstable = import nixpkgs-unstable {
       inherit system;
       config = nixpkgsConfig;
     };
     pkgs-pr = import nixpkgs-pr {
       inherit system;
       config = nixpkgsConfig;
     };
   };

   ### Shared specialArgs for all configurations
   specialArgs = system: {
     inherit inputs;
     pkgsExtra = pkgsExtra system;
     inherit (inputs) zen-browser ghostty; 
     #inherit (inputs) nurpkgs-repo-minegameYTB;
   };

   ### Home Manager desktop config (non-function call)
   homeManagerDesktopConfig = system: { config, pkgs, ... }: {
     home-manager.useGlobalPkgs = true;
     home-manager.useUserPackages = true;
     home-manager.users = lib.genAttrs users (username:
       import ./hm-profiles/desktop-profile-wrapped.nix {
         inherit username;
         extraModules = [ ./home-manager/configs/specific/nixos/stylix.nix ];
       });
     home-manager.extraSpecialArgs = specialArgs system;
   };

   ### Home Manager server config (non-function call)
   homeManagerServerConfig = system: { config, pkgs, ... }: {
     home-manager.useGlobalPkgs = true;
     home-manager.useUserPackages = true;
     home-manager.users = lib.genAttrs users (username:
       import ./hm-profiles/server-profile.nix { inherit username; });
     home-manager.extraSpecialArgs = specialArgs system;
   };

   ### Create standalone Home Manager config
   mkHome = system: username: home-manager.lib.homeManagerConfiguration {
     pkgs = import nixpkgs {
       inherit system;
       config = { allowUnfree = true; };
     };
     modules = [
       ({ config, pkgs, ... }: {
         nixpkgs.overlays = [ nur.overlays.default ];
         home.shellAliases = {
           nix = "nix --refresh -v --cores 2";
           home-manager = "home-manager -b bak";
           ls = "${pkgs.lsd}/bin/lsd";
           cat = "${pkgs.bat}/bin/bat";
           "ls.ori" = "${pkgs.coreutils}/bin/ls";
           "cat.ori" = "${pkgs.coreutils}/bin/cat";
         };
       })
       (import ./hm-profiles/desktop-profile.nix { inherit username; })
       stylix.homeModules.stylix
     ];
     extraSpecialArgs = {
       inherit inputs;
       pkgsExtra = pkgsExtra system;
       inherit (inputs) zen-browser nurpkgs-repo-minegameYTB;
     };
   };
 in {
   nixosConfigurations = {
     hp-probook = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerDesktopConfig "x86_64-linux")
       ];
     };
     hp-240 = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerDesktopConfig "x86_64-linux")
       ];
     };
     vm-desktop-efi = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerDesktopConfig "x86_64-linux")
       ];
     };
     vm-desktop-bios = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerDesktopConfig "x86_64-linux")
       ];
     };
     vm-desktop-bios-virtio = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerDesktopConfig "x86_64-linux")
       ];
     };
     vm-no-gui-efi = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerServerConfig "x86_64-linux")

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
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerServerConfig "x86_64-linux")
       ];
     };
     vm-no-gui-bios-virtio = lib.nixosSystem {
       system = "x86_64-linux";
       ### Inject pkgs attr with options
       pkgs = pkgsFor "x86_64-linux";
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
         (homeManagerServerConfig "x86_64-linux")
       ];
     };
   };

   ### Multi-architecture home-manager configs
   homeConfigurations = lib.listToAttrs (
     lib.concatMap (username:
       lib.concatMap (system: [{
         name = "${username}@${system}";
         value = mkHome system username;
       }]) systems
     ) users
   );
 };
}
