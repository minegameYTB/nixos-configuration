### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)
### Remade to split machine configuration to ./machine.nix nix expression

### (Minegame YTB 2025)

{
  description = "A flake with my configuration !";

  ### Declare inputs (nixpkgs-main, unstable, hm, stylix...)
  inputs = {
    ### Main repo
    nixpkgs-main.url = "github:NixOS/nixpkgs/nixos-25.11";

    ### Note: to test PR (with a flake configuration):
    ### github:username/<repo-name>?ref=pull/<PR number>/head

    ### Other nixpkgs repos
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # pkgsUnstable attr in flake
    #ctrl-os.url = "https://channels.ctrl-os.com/channel/ctrlos-24.05.tar.xz"; # pkgs-lts attr in flake

    ### Specific nixpkgs branch (staging or master (or even PR branch))
    #nixpkgs-master.url = "github:NixOS/nixpkgs/034c0f3a92afae7fd757537058c060720844c004"; # pkgs-master attr in flake
    #nixpkgs-pr.url = "github:NixOS/nixpkgs?ref=pull/424686/head"; # pkgs-pr attr in flake

    ### Other repos (non-nixpkgs but specific for a software or distant overlays) (pass this repos with specialArgs (with inputs in it))
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake"; # (inputs) zen-browser attr in config (extend this to a overlays later)
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    nur = {
      url = "github:nix-community/nur"; # nur attr in config (already extended with a overlay (see overlay function))
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database"; # (inputs) nix-index-database attr in config (distant flake modules available with inputs attr)
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    #nurpkgs-repo-minegameYTB.url = "github:minegameYTB/nurpkgs-repo"; # (inputs) nurpkgs-repo-minegameYTB attr in config (extend this later when enable for pkgs)
    #ghostty.url = "github:ghostty-org/ghostty/5306e7cf567ccb37028701a00504bcf28484b155"; # (inputs) ghostty attr in config (for pkgs, extend with a particular name to avoid attr conflict)

    ### Distant flake modules
    declarative-flatpak.url = "github:in-a-dil-emma/declarative-flatpak/v4.1.1"; # (inputs) declarative-flatpak attr in config (distant flake modules available with inputs attr)

    lazyvim = {
      url = "github:pfassina/lazyvim-nix"; # (inputs) lazyvim-nix attr in config (distant flake modules)
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    ### Pinned repo (to ensure overall consistency of the flake) (manually update this (to test if works correctly btw))
    # Home-manager - release-25.11 (8 Jan 2026)
    home-manager = {
      url = "github:nix-community/home-manager/82fb7dedaad83e5e279127a38ef410bcfac6d77c";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    # Stylix - release-25.11 (8 Jan 2026)
    stylix.url = "github:danth/stylix/55380d322f095ec9bc574f66f2870f19db46e6a1";

    # nixGL - fix warning stdenv hostPlatform.system
    nixgl.url = "github:nix-community/nixGL/d0cd6aab4e02279c8af82870921971855945fe29";

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
      url = "github:nix-community/lanzaboote/v0.4.2"; # imported as a external flake modules (test this time to time bcause secure-boot implementation (setup a vm to test this))
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
      #nurpkgs-repo-minegameYTB,

      ### External flake modules
      stylix,
      home-manager,
      lanzaboote,
      lazyvim,

      ### Sources for 3rd part software
      #ghostty,
      zen-browser,
      nixgl,
      ...
    }@inputs:

    ### Declare function here
    let
      ### User to install home-manager configuration (replace this if you change username if you fork this repo)
      users = [ "minegame" ];

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
          name = "nixpkgs-patched-455370";
          src = nixpkgs-main;
          patches = [
            (builtins.fetchurl {
              ### Add ".patch" to get this link for a PR
              url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/455370.patch";
              sha256 = "0ndpfv11q7rdm11zspm712g7c0lmjfi2jihp3vqy62zx24v78bm9";
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
        inherit inputs;
        inherit (inputs)
          zen-browser
          #ghostty
          #nurpkgs-repo-minegameYTB
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
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            (import ./hm-profiles/desktop-profile.nix { inherit username; })
            stylix.homeModules.stylix

            (overlay system)

            ### Import specific expression for standalone hm (move futur function here)
            ./home-manager/configs/specific/standalone
          ];
          extraSpecialArgs = {
            inherit inputs;
            inherit (inputs) zen-browser nurpkgs-repo-minegameYTB;
          };
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
