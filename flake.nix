### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
 description = "A flake with my configuration";

 inputs = {
   ### Main repo (prepare nixos 25.05)
   nixpkgs-main.url = "github:NixOS/nixpkgs/nixos-unstable";

   ### To test a PR on a flake:
   ### github:username/repo?ref=pull/<PR number>/head

   ### Other nixpkgs repos
   ctrl-os.url = "https://channels.ctrl-os.com/channel/ctrlos-24.05.tar.xz";
   nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
   nixpkgs-24-11.url = "github:NixOS/nixpkgs/nixos-24.11";
   #nixpkgs-25-05.url = "github:NixOS/nixpkgs/nixos-25.05";
   nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
   
   ### Upstream nixpkgs repo (pin git hash)
   #nixpkgs-master.url = "github:NixOS/nixpkgs/034c0f3a92afae7fd757537058c060720844c004";

   ### Temporairy use PR 
   #nixpkgs-pr.url = "github:NixOS/nixpkgs?ref=pull/424686/head";

   ### Other repos 
   home-manager = {
     url = "github:nix-community/home-manager/5d61767c8dee7f9c66991335795dbca9e801c25a";
     inputs.nixpkgs.follows = "nixpkgs-main";
   };
   zen-browser = {
     url = "github:0xc000022070/zen-browser-flake";
     inputs.nixpkgs.follows = "nixpkgs-main";
   };
   nur = {
     url = "github:nix-community/nur";
     inputs.nixpkgs.follows = "nixpkgs-main";
   };
   ### Stylix - future release-25.11 branch (Oct 2025)
   stylix.url = "github:danth/stylix/09022804b2bcd217f3a41a644d26b23d30375d12";
   #nix-flatpak.url = "github:gmodena/nix-flatpak/latest"; # For NixOS flatpak
   declarative-flatpak.url = "github:in-a-dil-emma/declarative-flatpak/v4.0.0"; # For HM standalone
   nix-index-database = {
     url = "github:nix-community/nix-index-database";
     inputs.nixpkgs.follows = "nixpkgs-main";
   };
   #nurpkgs-repo-minegameYTB.url = "github:minegameYTB/nurpkgs-repo";
   #ghostty.url = "github:ghostty-org/ghostty/5306e7cf567ccb37028701a00504bcf28484b155";
   #lazyvim.url = "github:pfassina/lazyvim-nix";

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
     inputs.nixpkgs.follows = "nixpkgs-main";
   };
 };

 outputs = {
   ### Primary sources
   self,
   nixpkgs-main,

   ### Other nixpkgs sources
   ctrl-os,
   nixpkgs-23-11,
   nixpkgs-24-11,
   #nixpkgs-25-05,
   nixpkgs-unstable,
   #nixpkgs-master,
   #nixpkgs-pr,

   ### Other sources
   stylix,
   home-manager,
   nur,
   #nix-flatpak,
   declarative-flatpak,
   #nurpkgs-repo-minegameYTB,
   lanzaboote,
   #lazyvim,

   ### Sources for 3rd part software
   #ghostty,
   zen-browser,
   ...
 }@inputs:

 let
   ### System variables
   ### Nixpkgs config (unfree allowed)
   nixpkgsConfig = {
     allowUnfree = true;
   };  
   lib = nixpkgs-main.lib;

   ### Overlay
   overlay = ({ config, pkgs, ... }: {
     nixpkgs.overlays = [
       nur.overlays.default
     ];
   });

   ### Supported systems (x86_64 + ARM)
   systems = [ "x86_64-linux" "aarch64-linux" ];
   users = [ "minegame" ];

   ### Create patched nixpkgs for each system
   nixpkgs-patched = system: (import nixpkgs-main { inherit system; }).applyPatches {
     #name = "nixpkgs-patched-421549";
     src = nixpkgs-main;
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
   pkgsFor = system: import nixpkgs-main {
     inherit system;
     config = nixpkgsConfig;
   };

   ### Other sources (pkgs set)
   pkgsExtra = system: {
     pkgs-lts = import ctrl-os {
       inherit system;
       config = nixpkgsConfig;
     };
     pkgs-23-11 = import nixpkgs-23-11 {
       inherit system;
       config = nixpkgsConfig;
     };
     pkgs-24-11 = import nixpkgs-24-11 {
       inherit system;
       config = nixpkgsConfig;
     };
     #pkgs-25-05 = import nixpkgs-25-05 {
     #  inherit system;
     #  config = nixpkgsConfig;
     #};
     pkgs-unstable = import nixpkgs-unstable {
       inherit system;
       config = nixpkgsConfig;
     };
     #pkgs-master = import nixpkgs-master {
     #  inherit system;
     #  config = nixpkgsConfig;
     #};
     #pkgs-pr = import nixpkgs-pr {
     #  inherit system;
     #  config = nixpkgsConfig;
     #};
   };

   ### Shared specialArgs for all configurations
   specialArgs = system: {
     inherit inputs;
     pkgsExtra = pkgsExtra system;
     inherit (inputs)
       zen-browser 
       #ghostty
     ; 
     #inherit (inputs) nurpkgs-repo-minegameYTB;
   };

   ### Home Manager desktop config (non-function call)
   homeManagerDesktopConfig = system: { config, pkgs, ... }: {
     home-manager.useGlobalPkgs = true;
     home-manager.useUserPackages = true;
     home-manager.users = lib.genAttrs users (username:
       import ./hm-profiles/desktop-profile-wrapped.nix {
         inherit username;
         extraModules = [ ./home-manager/configs/specific/nixos ];
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
     pkgs = import nixpkgs-main {
       inherit system;
       config = { allowUnfree = true; };
     };
     modules = [
       (import ./hm-profiles/desktop-profile.nix { inherit username; })
       stylix.homeModules.stylix
       
       ### Import specific expression for standalone hm (move futur function here)
       ./home-manager/configs/specific/standalone
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
         
         ### Global overlay settings
         overlay

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

         ### Global overlay settings
         overlay

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

         ### Global overlay settings
         overlay

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

         ### Global overlay settings
         overlay

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

         ### Global overlay settings
         overlay

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

         ### Global overlay settings
         overlay

         ### Hostname config
         { networking.hostName = "nixos-pve-srv"; }

         ### Home-manager module
         home-manager.nixosModules.home-manager
         (homeManagerServerConfig "x86_64-linux")

         ### Add wrapper expression module
         (import ./profiles/base-profiles/vm-no-gui-wrapped.nix {
           extraModules = [
             #./configurations/configs/specific/vm/guest/nextcloud.nix
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

         ### Global overlay settings
         overlay

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

         ### Global overlay settings
         overlay

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
