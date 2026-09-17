{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  ### Nix Settings
  ### Aligned with configurations/configs/common/system-opts/nix-settings.nix,
  ### restricted to user-level options (`trusted-users` stays root-level).
  nix = {
    ### Nix package used to generate/validate nix.conf and for the gc service
    ### (required once nix.settings is set)
    package = pkgs.nix;

    ### Point NIX_PATH and the flake registry at the flake-pinned nixpkgs
    ### (follows flake.lock), same as on NixOS.
    nixPath = [ "nixpkgs=${inputs.nixpkgs-main}" ];
    registry.nixpkgs = {
      to = {
        type = "path";
        path = inputs.nixpkgs-main.outPath;
      };
    };

    settings = {
      warn-dirty = false;
      auto-optimise-store = true;
      download-buffer-size = 134217728; # 128M for download buffer
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 2;
      cores = 2;
      substituters = [
        #"https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        #"cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      randomizedDelaySec = "45min";
      options = "--delete-older-than 14d --max-freed 30G";
    };
  };

  ### Initialise nur on home-manager standalone (already the case on hm-module on NixOS)
  nixpkgs.overlays = [ inputs.nur.overlays.default ];

  ### Nix package
  home.packages = with pkgs; [ nix ];

  ### Nvd diff hook
  home.activation = {
    report-changes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ### Define strict variable on this context
      report-changes(){
        echo -e "\n===================================="
        echo      "| Running nvd diff to show changes |"
        echo -e   "====================================\n"

        ### Scoped PATH (append, never overwrite): export would clobber PATH
        ### for every activation step running after writeBoundary.
        ### Variable found in activation script
        PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin:$PATH" nvd diff $oldGenPath $newGenPath
        echo ""
      }

      ### Execute report-changes hook
      report-changes
    '';
  };
}
