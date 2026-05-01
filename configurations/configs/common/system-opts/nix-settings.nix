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
      #substituters = [
      #  "https://minegameytb.cachix.org"
      #];
      #trusted-public-keys = [
      #  "minegameytb.cachix.org-1:JvOgXYklqCayYEJWzlt0Sqc6zvs0S65ZZsWHYWh7qnc="
      #];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      randomizedDelaySec = "45min";
      options = "--delete-older-than 14d --max-freed 15G";
    };
    optimise = {
      automatic = true;
      dates = [ "monthly" ];
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

  ### Override nixos-rebuild to use -F flag by default
  nixpkgs.overlays = [
    (self: super: {
      nixos-rebuild-ng = super.nixos-rebuild-ng.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ super.makeWrapper ];

        postFixup = (oldAttrs.postFixup or "") + ''
          wrapProgram $out/bin/nixos-rebuild \
            --run 'MAGENTA="\e[35m"; RESET="\e[0m"; echo -e "$MAGENTA""warning:$RESET This custom modification of nixos-rebuild use --flake (or -F) flag by default (remove warning before merge to flake branch)" >&2' \
            --add-flags "-F"
        '';
      });
    })
  ];
}
