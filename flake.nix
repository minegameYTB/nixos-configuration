### Flake originally based on https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users
### Refactored to split machine configuration into ./machine.nix

### (Minegame YTB 2025)

{
  description = "A flake with my configuration !";

  ### Inputs (nixpkgs-main, unstable, hm, stylix...)
  inputs = {
    ### Main nixpkgs channel
    nixpkgs-main.url = "github:NixOS/nixpkgs/nixos-26.05";

    ### To test a PR: github:username/repo?ref=pull/<PR number>/head

    ### Additional nixpkgs channels
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-25-11.url = "github:NixOS/nixpkgs/nixos-25.11";
    #ctrl-os.url = "https://channels.ctrl-os.com/channel/ctrlos-24.05.tar.xz";

    ### Specific nixpkgs revisions (staging, master, or PR branches)
    #nixpkgs-master.url = "github:NixOS/nixpkgs/034c0f3a92afae7fd757537058c060720844c004";
    nixpkgs-pr.url = "github:NixOS/nixpkgs?ref=pull/537215/head";

    ### Kernel
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    ### External non-nixpkgs repos (overlays, software) — passed via specialArgs
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    ### Remote flake modules
    declarative-flatpak.url = "github:in-a-dil-emma/declarative-flatpak/v4.1.7";

    ### Pinned inputs (lock file ensures reproducibility; update manually after testing)
    # Home-manager - release-26.05 (18 Jul 2026)
    home-manager = {
      url = "github:nix-community/home-manager/4ce190229c73d44536caa7072f6308fb2d8feeb3";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    # Stylix - release-26.05 (14 Jul 2026)
    stylix = {
      url = "github:danth/stylix/2245fa9e16034149b6501834b99863a486e94725";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    # Lazyvim-nix - main
    lazyvim = {
      url = "github:pfassina/lazyvim-nix/v16.0.0";
      inputs.nixpkgs.follows = "nixpkgs-main";
    };

    ### Non-flake repos (theming, dotfiles)
    catppuccin-wallpapers = {
      url = "github:zhichaoh/catppuccin-wallpapers";
      flake = false;
    };

    dotfiles-minegameYTB = {
      url = "github:minegameYTB/dotfiles";
      flake = false;
    };

    ### Utility inputs (both flake and non-flake)
    ### StevenBlack/hosts imported as non-flake for /etc/hosts management
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

  ### Outputs
  outputs =
    {
      self,
      nixpkgs-main,
      ...
    }@inputs:

    let
      ### Users configuration (global features + per-user profiles)
      hmProfiles = import ./hm-profiles/users.nix;
      globalFeatures = hmProfiles.globalFeatures;
      userConfigs = hmProfiles.users;
      # List of usernames for backward compat with modules expecting a list
      users = builtins.attrNames userConfigs;
      properties = {
        i18n = "fr_FR.UTF-8";
        keyMap = "fr";
        x11KeyMap = "fr";
      };

      ### Git revision (short hash) for versioning
      rev = self.shortRev or self.dirtyShortRev or "unknown";

      ### Branch name from .branch file at repo root
      branch =
        let
          f = ./. + "/.branch";
        in
        if builtins.pathExists f then
          builtins.replaceStrings [ "/" "#" ] [ "-" "-" ] (lib.removeSuffix "\n" (builtins.readFile f))
        else
          null;

      ### Repo URL — single source of truth for packaging and /etc/os-release
      repoUrl = (import ./lib/repo.nix).url;

      ### Supported systems (also used by home-manager standalone)
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      ### Allow unfree packages
      nixpkgsConfig = {
        allowUnfree = true;
        #permittedInsecurePackages = [ "electron-39.8.10" ];
      };

      inherit (nixpkgs-main) lib;

      ### Global overlay (imported from ./overlay.nix)
      overlay =
        system:
        import ./overlay.nix {
          inherit
            self
            system
            inputs
            lib
            rev
            branch
            repoUrl

            ### Nixpkgs option variable
            nixpkgsConfig
            ;
        };

      ### nixpkgs with out-of-tree patches applied. Name embeds the base
      ### nixpkgs rev + the patches (lib/nixpkgs-patches.nix) so pkgsPatched
      ### builds are traceable in the store / nix tools.
      nixpkgs-patched =
        system:
        let
          pkgs = nixpkgs-main.legacyPackages.${system};
          patches = import ./lib/nixpkgs-patches.nix { inherit pkgs lib; };
        in
        pkgs.applyPatches {
          name = "nixpkgs-patched-${nixpkgs-main.shortRev}-${patches.name}";
          src = nixpkgs-main;
          inherit (patches) patches;
        };

      pkgsPatched =
        system:
        import (nixpkgs-patched system) {
          inherit system;
          config = nixpkgsConfig;
        };

      pkgsFor =
        system:
        import nixpkgs-main {
          inherit system;
          config = nixpkgsConfig;
        };

      ### Global specialArgs (passed to all NixOS and home-manager modules)
      specialArgs = system: {
        inherit
          self
          inputs
          globalFeatures
          userConfigs
          users
          properties
          ;
      };

      ### Home-manager config — single entry for all users
      homeManagerConfig =
        system:
        {
          config,
          pkgs,
          userOverrides ? { },
          ...
        }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users = lib.mapAttrs (
              username: _:
              import ./hm-profiles/users/${username}/default.nix {
                inherit
                  username
                  globalFeatures
                  userConfigs
                  userOverrides
                  inputs
                  ;
              }
            ) userConfigs;
            extraSpecialArgs = specialArgs system // {
              inherit
                globalFeatures
                userConfigs
                userOverrides
                inputs
                ;
            };
          };
        };

      ### Standalone home-manager (for non-NixOS Linux)
      mkHome =
        system: username:
        let
          userCfg = userConfigs.${username};
          hasStylix = builtins.elem "gnome" (globalFeatures ++ userCfg.hmFeatures);
          userOverrides = { };
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            (import ./hm-profiles/users/${username}/default.nix {
              inherit
                username
                globalFeatures
                userConfigs
                userOverrides
                inputs
                ;
            })
            (overlay system)

            ### Standalone-specific configuration
            ./home-manager/configs/specific/standalone
          ]
          ++ lib.optionals hasStylix [ inputs.stylix.homeModules.stylix ];
          extraSpecialArgs = specialArgs system // {
            inherit
              globalFeatures
              userConfigs
              userOverrides
              inputs
              ;
          };
        };

      mkHomeAttr = username: system: {
        name = "${username}@${system}";
        value = mkHome system username;
      };

    in
    {
      ### Formatter (unified across all architectures)
      formatter = lib.genAttrs systems (system: nixpkgs-main.legacyPackages.${system}.nixfmt-tree);

      ### Dev shell (used by build.sh wrapper)
      devShells = lib.genAttrs systems (system: {
        default = (pkgsFor system).mkShell {
          packages = with pkgsFor system; [
            gnumake
            nix.out
            unzip
            gitMinimal
            jq
            cacert
            deadnix
            shellcheck
          ];
        };
      });

      ### Flake packages — uses overlay (which delegates to pkgs/default.nix)
      packages = lib.genAttrs systems (
        system:
        let
          pkgsWithOverlay = import nixpkgs-main {
            inherit system;
            config = nixpkgsConfig;
            overlays =
              (import ./overlay.nix {
                inherit
                  self
                  system
                  inputs
                  lib
                  rev
                  branch
                  repoUrl
                  nixpkgsConfig
                  ;
              }).nixpkgs.overlays;
          };
        ### callPackage injects override/overrideDerivation functors into the
        ### pkgsConfig attrset — strip them so `nix flake show` doesn't warn
        ### about non-derivation packages.
        pkgsConfig = lib.removeAttrs pkgsWithOverlay.pkgsConfig [
          "override"
          "overrideDerivation"
        ];
      in
      pkgsConfig

        ### ISO images auto-discovery
        # Every nixosConfig starting with "iso-" gets picked up automatically
        # and exposed as a flake package. mapAttrs' + filterAttrs does the job
        # — no more manual listing when adding a new variant.
        // lib.optionalAttrs (system == "x86_64-linux") (
          lib.mapAttrs' (name: config: lib.nameValuePair name config.config.system.build.isoImage) (
            lib.filterAttrs (n: _: lib.hasPrefix "iso-" n) self.nixosConfigurations
          )
        )
      );

      ### NixOS configurations (defined in machine.nix)
      nixosConfigurations = import ./machine.nix {
        inherit
          lib
          overlay
          inputs
          pkgsFor
          pkgsPatched
          specialArgs
          homeManagerConfig
          rev
          branch
          ;

        inherit (inputs) home-manager;
      };

      ### Home-manager standalone configurations (one per user/system)
      homeConfigurations = lib.listToAttrs (
        lib.concatMap (username: lib.concatMap (system: [ (mkHomeAttr username system) ]) systems) users
      );
    };
}
