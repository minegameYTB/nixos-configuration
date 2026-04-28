### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)
### Remade to split machine configuration to ./machine.nix nix expression

### (Minegame YTB 2025)

{
  description = "A flake with my configuration !";

  ### Declare inputs (nixpkgs-main, unstable, hm, stylix...)
  inputs = {
    ### Main repo (prepare NixOS 26.05)
    nixpkgs-main.url = "github:NixOS/nixpkgs/nixos-unstable";

    ### Note: to test PR (with a flake configuration):
    ### github:username/<repo-name>?ref=pull/<PR number>/head

    ### Other nixpkgs repos
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    #ctrl-os.url = "https://channels.ctrl-os.com/channel/ctrlos-24.05.tar.xz";

    ### Specific nixpkgs branch (staging or master (or even PR branch))
    #nixpkgs-master.url = "github:NixOS/nixpkgs/034c0f3a92afae7fd757537058c060720844c004";
    #nixpkgs-pr.url = "github:NixOS/nixpkgs?ref=pull/424686/head";

    ### Other repos (non-nixpkgs but specific for a software or distant overlays) (pass this repos with specialArgs (with inputs in it))
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    ### Distant flake modules
    declarative-flatpak.url = "github:in-a-dil-emma/declarative-flatpak/v4.1.6";

    ### Pinned repo (to ensure overall consistency of the flake) (manually update this (to test if works correctly btw))
    # Home-manager - main (6 Apr 2026)
    home-manager = {
      url = "github:nix-community/home-manager/508daf831ab8d1b143d908239c39a7d8d39561b2";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    # Stylix - master (22 Apr 2026)
    stylix.url = "github:danth/stylix/84971726c7ef0bb3669a5443e151cc226e65c518";

    # Lazyvim-nix - main (2 Apr 2026)
    lazyvim = {
      url = "github:pfassina/lazyvim-nix/c1c27d9b3fd74d243a34985c5440a14aa0c2a169";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    ### End of pinned repos

    ### Non flake repos (for rice and dotfiles)
    catppuccin-wallpapers = {
      url = "github:zhichaoh/catppuccin-wallpapers";
      flake = false;
    };

    dotfiles-minegameYTB = {
      url = "github:minegameYTB/dotfiles";
      flake = false;
    };

    ### Utilities (flake and non flake repos)
    ### Import blocklist as non-flake for /etc/hosts
    blocklist = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    glfOS-modules = {
      url = "git+https://framagit.org/gaming-linux-fr/glf-os/glf-os.git?ref=main"; # For nvidia settings module
      inputs.nixpkgs.follows = "nixpkgs-main";
    };
  };

  ### Declare outputs for configuration (inputs attr is inject here)
  outputs =
    {
      ### Core (include self to auto-refere eventually use local packages with an overlay)
      self,
      nixpkgs-main,

      ### Other nixpkgs sources
      #ctrl-os,
      nixpkgs-unstable,
      #nixpkgs-master,
      #nixpkgs-pr,

      ### Other sources
      nur,
      declarative-flatpak,

      ### External flake modules
      stylix,
      home-manager,
      lanzaboote,
      lazyvim,

      ### Sources for 3rd part software
      zen-browser,
      ...
    }@inputs:

    ### Declare function here
    let
      ### User for user configuration and home manager standalone, please change this username when you fork this repo, thanks !
      users = [ "minegame" ];
      description = "Minegame YTB";

      ### System supported for this config (to use on home-manager for example)
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      ### Nixpkgs specific configuration (allow non-free app and software)
      nixpkgsConfig = {
        allowUnfree = true;
      };

      ### Lib from nixpkgs-main
      inherit (nixpkgs-main) lib;

      ### Global overlay configuration (import global overlay in ./overlay.nix)
      overlay =
        system:
        import ./overlay.nix {
          inherit
            system
            inputs
            lib

            ### Nixpkgs option variable
            nixpkgsConfig
            ;
        };

      ### Setup nixpkgs-patched (nixpkgs with custom patch)
      nixpkgs-patched =
        ### "system:" receive arch from argument (for example, pkgsPatched "arch" become pkgsPatched "system = "arch" in evaluation, same logic for function that use defined attribute)
        system:
        (import nixpkgs-main { inherit system; }).applyPatches {
          name = "nixpkgs-patched";
          src = nixpkgs-main;
          patches = [
            (builtins.fetchurl {
              ### Add ".patch" to get this link for a PR
              url = "https://github.com/NixOS/nixpkgs/commit/3b4a0798b7c01d90ef25015e2dbdb47fe2a83fc2.patch";
              sha256 = "07hm2y2b39p85a7p8yyyxmidv5jzxxrvj4bl36l3nmq4z2cp5hpj";
            })

            ### Local patch
            #./configurations/patch/nixpkgs/0000-qemu-fix-version.patch
            #./configurations/patch/nixpkgs/0000-libvirt-update.patch
          ];
        };

      ### Declare pkgsPatched as a usable pkgs arg
      pkgsPatched =
        system:
        import (nixpkgs-patched system) {
          inherit system;
          config = nixpkgsConfig;
        };

      ### Same for pkgsFor (normal nixpkgs-main w/out patches)
      pkgsFor =
        system:
        import nixpkgs-main {
          inherit system;
          config = nixpkgsConfig;
        };

      ### Declare specialArgs globally (pass inputs and other info through this function/attribute)
      specialArgs = system: {
        inherit inputs users description;
        inherit (inputs) zen-browser;
      };

      ### Declare Home-manager function (for desktop and full CLI)
      homeManagerDesktopConfig =
        system:
        { config, pkgs, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            ### Same logic for "users:" and "users" function
            users = lib.genAttrs users (
              username:
              import ./hm-profiles/desktop-profile-wrapped.nix {
                inherit username;
                extraModules = [ ./home-manager/configs/specific/nixos ];
              }
            );
            extraSpecialArgs = specialArgs system;
          };
        };

      homeManagerServerConfig =
        system:
        { config, pkgs, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users = lib.genAttrs users (
              username: import ./hm-profiles/server-profile.nix { inherit username; }
            );
            extraSpecialArgs = specialArgs system;
          };
        };

      ### Declare mkHome function (home manager standard configuration on homeConfigurations attribute on hm standalone setup)
      mkHome =
        system: username:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            (import ./hm-profiles/desktop-profile.nix { inherit username; })
            stylix.homeModules.stylix

            (overlay system)

            ### Import specific expression for standalone hm (move futur function here)
            ./home-manager/configs/specific/standalone
          ];
          extraSpecialArgs = specialArgs system;
        };

      mkHomeAttr = username: system: {
        name = "${username}@${system}";
        value = mkHome system username;
      };

    in
    {
      ### Formatter
      formatter.x86_64-linux = nixpkgs-main.legacyPackages.x86_64-linux.nixfmt-tree;

      ### Import NixOS configurtion in a file called machine.nix (with needed argument defined as a funtion in "let [...] in" section)
      nixosConfigurations = import ./machine.nix {
        ### Pass attribute from this flake directly on the expression
        inherit
          ### Core
          lib
          overlay
          inputs
          pkgsFor
          pkgsPatched
          specialArgs
          homeManagerDesktopConfig
          homeManagerServerConfig
          ;

        ### Import home-manager variable as inputs.home-manager... internally
        inherit (inputs) home-manager;
      };

      ### Declare home-manager standalone configuration
      homeConfigurations = lib.listToAttrs (
        lib.concatMap (username: lib.concatMap (system: [ (mkHomeAttr username system) ]) systems) users
      );
    };
}
