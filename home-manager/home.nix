{ config, pkgs, ... }:

{

  imports = [
    ./configs/common/cli-packages.nix
    ./configs/common/custom-pkgs.nix
    ./configs/common/config.nix
    ./configs/common/neovim.nix

    ### Import home-manager external modules (nixos specific)
    ./config-modules
  ];

  home.stateVersion = "24.05"; # Please read the comment before changing.
}
