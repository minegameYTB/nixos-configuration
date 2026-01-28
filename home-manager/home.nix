{ config, pkgs, ... }:

{

  imports = [
    ./configs/common

    ### Import home-manager external modules (nixos specific)
    ./config-modules
  ];

  home.stateVersion = "24.05"; # Please read the comment before changing.
}
