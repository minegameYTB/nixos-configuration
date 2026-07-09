### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)
### Remade to split machine configuration to ./machine.nix nix expression

### (Minegame YTB 2025)

{
  description = "A flake with my configuration !";

  ### Declare inputs (nixpkgs-main, unstable, hm, stylix...)
  inputs = {
    ### Main repo
    nixpkgs-main.url = "github:NixOS/nixpkgs/nixos-26.05";

    ### Note: to test PR (with a flake configuration):
    ### github:username/<repo-name>?ref=pull/<PR number>/head

    ### Other nixpkgs repos
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-25-11.url = "github:NixOS/nixpkgs/nixos-25.11";
    #ctrl-os.url = "https://channels.ctrl-os.com/channel/ctrlos-24.05.tar.xz";

    ### Specific nixpkgs branch (staging or master (or even PR branch))
    #nixpkgs-master.url = "github:NixOS/nixpkgs/034c0f3a92afae7fd757537058c060720844c004";
    nixpkgs-pr.url = "github:NixOS/nixpkgs?ref=pull/537215/head";

    ### Kernel
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

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
    declarative-flatpak.url = "github:in-a-dil-emma/declarative-flatpak/v4.1.7";

    ### Pinned repo (to ensure overall consistency of the flake) (manually update this (to test if works correctly btw))
    # Home-manager - release-26.05 (8 Jun 2026)
    home-manager = {
      url = "github:nix-community/home-manager/4eb4fec41674d5b059aa2eedf0f98453890546fa";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    # Stylix - release-26.05 (6 Jun 2026)
    stylix = {
      url = "github:danth/stylix/54fa19702f4f2c7f6a981a92850678933588af9a";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    # Lazyvim-nix - main
    lazyvim = {
      url = "github:pfassina/lazyvim-nix/v16.0.0";
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
      url = "git+https://framagit.org/gaming-linux-fr/glf-os/glf-os.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };
  };

  ### Declare outputs for configuration (inputs attr is inject here)
  outputs =
    {
      ### Core (include self to auto-refere eventually use local packages with an overlay)
      self,
      nixpkgs-main,
      ...
    }@inputs:

    ### Declare function here
    let
      ### User for user configuration and home manager standalone, please change this username when you fork this repo, thanks !
      users = [ "minegame" ];
      description = "Minegame YTB";
      properties = {
        i18n = "fr_FR.UTF-8";
        keyMap = "fr";
        x11KeyMap = "fr";
      };

      ### System supported for this config (to use on home-manager for example)
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      ### Nixpkgs specific configuration (allow non-free app and software)
      nixpkgsConfig = {
        allowUnfree = true;
        #permittedInsecurePackages = [ "electron-39.8.10" ];
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
        nixpkgs-main.legacyPackages.${system}.applyPatches {
          name = "nixpkgs-patched";
          src = nixpkgs-main;
          patches = [
            (builtins.fetchurl {
              ### Add ".patch" to get this link for a PR
              url = "https://github.com/NixOS/nixpkgs/pull/537215.patch";
              sha256 = "0q8rzbrch578krfkpr16j9j48pyhd0angypqbb4flgkyzfigg70c";
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
        inherit
          inputs
          users
          description
          properties
          ;
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
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            (import ./hm-profiles/desktop-profile.nix { inherit username; })
            inputs.stylix.homeModules.stylix

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
      ### Formatter (unified for all architectures)
      formatter = lib.genAttrs systems (system: nixpkgs-main.legacyPackages.${system}.nixfmt-tree);

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
