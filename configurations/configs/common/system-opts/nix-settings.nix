{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Nix Settings
  nix = {
    ### Use nix from ctrl os
    #package = pkgs.pkgs-lts.nix;

    ### Directory relative to channel are removed with the service "nix-channel-rm-dirs.service"
    channel.enable = false;
    #registry.nix-custom-repo.to =
    #  owner = "minegameYTB";
    #  repo = "nix-custom-repo";
    #  type = "github";
    #};
    settings = {
      warn-dirty = false;
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
      download-buffer-size = 134217728; # 128M for download buffer
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 2;
      cores = 2;
      substituters = [
        "https://minegameytb.cachix.org"
      ];
      trusted-public-keys = [
        "minegameytb.cachix.org-1:JvOgXYklqCayYEJWzlt0Sqc6zvs0S65ZZsWHYWh7qnc="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  ### Ctrl-os substitutes (custom option (defined in /configurations/modules/nix/ctrl-os-substitutes.nix))
  #ctrl-os.substitutes.enable = true;

  system = {
    ### Disable some nixos other command
    tools = {
      nixos-option.enable = false;
      nixos-build-vms.enable = false;
      nixos-install.enable = false;
    };
  };
}
