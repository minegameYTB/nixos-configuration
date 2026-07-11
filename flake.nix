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
      ### Username for user config and home-manager standalone (change when forking)
      users = [ "minegame" ];
      description = "Minegame YTB";
      properties = {
        i18n = "fr_FR.UTF-8";
        keyMap = "fr";
        x11KeyMap = "fr";
      };

      ### Git revision (short hash) for versioning
      rev = self.shortRev or self.dirtyShortRev or "unknown";

      ### Branch detection: tries CI env vars, then local git HEAD (requires --impure)
      branch = let
        envBranch = builtins.getEnv "BRANCH";
        ghBranch = builtins.getEnv "GITHUB_REF_NAME";
        ciBranch = builtins.getEnv "CI_COMMIT_REF_NAME";
        pwd = builtins.getEnv "PWD";
        gitHead = pwd + "/.git/HEAD";
        fromGit =
          if pwd != "" && builtins.pathExists gitHead then
            let
              content = builtins.readFile gitHead;
              match = builtins.match "ref: refs/heads/(.+)\n" content;
            in
              if match != null then builtins.head match else null
          else null;
      in
        if envBranch != "" then builtins.replaceStrings ["/" "#"] ["-" "-"] envBranch
        else if ghBranch != "" then builtins.replaceStrings ["/" "#"] ["-" "-"] ghBranch
        else if ciBranch != "" then builtins.replaceStrings ["/" "#"] ["-" "-"] ciBranch
        else if fromGit != null then builtins.replaceStrings ["/" "#"] ["-" "-"] fromGit
        else null;

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
          users
          description
          properties
          ;
      };

      ### Desktop home-manager config (GNOME)
      homeManagerDesktopConfig =
        system:
        { config, pkgs, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
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

      ### Server home-manager config (headless)
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

      ### Standalone home-manager (for non-NixOS Linux)
      mkHome =
        system: username:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            (import ./hm-profiles/desktop-profile.nix { inherit username; })
            inputs.stylix.homeModules.stylix

            (overlay system)

            ### Standalone-specific configuration
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
      ### Formatter (unified across all architectures)
      formatter = lib.genAttrs systems (system: nixpkgs-main.legacyPackages.${system}.nixfmt-tree);

      ### Flake packages (imports pkgs/default.nix for derivations)
      packages = lib.genAttrs systems (system:
        ((pkgsFor system).callPackage ./pkgs/default.nix {
          src = self.outPath;
          inherit rev branch;
        })
        // lib.optionalAttrs (system == "x86_64-linux") {
        iso-gnome = self.nixosConfigurations.iso-gnome.config.system.build.isoImage;
        iso-minimal = self.nixosConfigurations.iso-minimal.config.system.build.isoImage;
      });

      ### NixOS configurations (defined in machine.nix)
      nixosConfigurations = import ./machine.nix {
        inherit
          lib
          overlay
          inputs
          pkgsFor
          pkgsPatched
          specialArgs
          homeManagerDesktopConfig
          homeManagerServerConfig
          ;

        inherit (inputs) home-manager;
      };

      ### Home-manager standalone configurations (one per user/system)
      homeConfigurations = lib.listToAttrs (
        lib.concatMap (username: lib.concatMap (system: [ (mkHomeAttr username system) ]) systems) users
      );
    };
}
