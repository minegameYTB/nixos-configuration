{
  config,
  pkgs,
  pkgsExtra,
  inputs,
  ...
}:

{
  ### Nix Settings
  nix = {
    ### Use nix from ctrl os
    package = pkgsExtra.pkgs-lts.nix;

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
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 2;
      cores = 2;
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
  ctrl-os.substitutes.enable = true;

  system = {
    ### Enable nixos-rebuild-ng to replace nixos-rebuild legacy (take "config.system.tools.nixos-rebuild.enable" value to use value defind in this option as true)
    #rebuild.enableNg = config.system.tools.nixos-rebuild.enable; ### Remove this line in 26.05 release

    ### Disable some nixos other command
    tools = {
      nixos-option.enable = false;
      nixos-build-vms.enable = false;
      nixos-install.enable = false;
    };
  };
}
