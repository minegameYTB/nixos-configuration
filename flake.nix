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

    ### Remote flake modules
    declarative-flatpak.url = "github:in-a-dil-emma/declarative-flatpak/v4.1.7";

    ### Pinned inputs (lock file ensures reproducibility; update manually after testing)
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

      ### Replace problematic chars in branch names
      cleanBranchName = builtins.replaceStrings [ "/" "#" ] [ "-" "-" ];

      ### Dirty tree detection — true when working tree has uncommitted changes
      dirty = self ? dirtyShortRev || self ? dirtyRev;

      ### Branch detection: CI env vars → .branch file (pure) → .git/HEAD from PWD (impure)
      branch =
        let
          envBranch = builtins.getEnv "BRANCH";
          ghBranch = builtins.getEnv "GITHUB_REF_NAME";
          ciBranch = builtins.getEnv "CI_COMMIT_REF_NAME";

          ### For pure eval: read committed .branch file from flake source
          branchFile = ./. + "/.branch";
          fromBranchFile =
            if builtins.pathExists branchFile then
              lib.removeSuffix "\n" (builtins.readFile branchFile)
            else
              null;

          ### For impure eval: read .git/HEAD via PWD env
          pwd = builtins.getEnv "PWD";
          fromGit =
            if pwd != "" && builtins.pathExists (pwd + "/.git/HEAD") then
              let
                content = builtins.readFile (pwd + "/.git/HEAD");
                match = builtins.match "ref: refs/heads/(.+)\n" content;
              in
              if match != null then builtins.head match else null
            else
              null;

          raw =
            if envBranch != "" then
              cleanBranchName envBranch
            else if ghBranch != "" then
              cleanBranchName ghBranch
            else if ciBranch != "" then
              cleanBranchName ciBranch
            else if fromBranchFile != null then
              cleanBranchName fromBranchFile
            else if fromGit != null then
              cleanBranchName fromGit
            else
              null;
        in
        raw;

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

      ### nixpkgs with out-of-tree patches applied
      nixpkgs-patched =
        system:
        nixpkgs-main.legacyPackages.${system}.applyPatches {
          name = "nixpkgs-patched";
          src = nixpkgs-main;
          patches = [
            (builtins.fetchurl {
              ### Append ".patch" to the PR URL to get the patch
              url = "https://github.com/NixOS/nixpkgs/pull/537215.patch";
              sha256 = "0q8rzbrch578krfkpr16j9j48pyhd0angypqbb4flgkyzfigg70c";
            })

            ### Local patches (uncomment as needed)
            #./configurations/patch/nixpkgs/0000-qemu-fix-version.patch
            #./configurations/patch/nixpkgs/0000-libvirt-update.patch
          ];
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
                inherit globalFeatures userConfigs userOverrides inputs;
              }
            ) userConfigs;
            extraSpecialArgs = specialArgs system // {
              inherit globalFeatures userConfigs userOverrides inputs;
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
              inherit globalFeatures userConfigs userOverrides inputs;
            })
            (overlay system)

            ### Standalone-specific configuration
            ./home-manager/configs/specific/standalone
          ]
          ++ lib.optionals hasStylix [ inputs.stylix.homeModules.stylix ];
          extraSpecialArgs = specialArgs system // {
            inherit globalFeatures userConfigs userOverrides inputs;
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
        in
        pkgsWithOverlay.pkgsConfig

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
        lib.concatMap (username: lib.concatMap (system: [ (mkHomeAttr username system) ]) systems) (
          builtins.attrNames users
        )
      );
    };
}
