{ config, pkgs, ... }:

{

  imports = [
    ./configs/common

    ### Import home-manager external modules (nixos specific)
    ./config-modules
  ];

  home.stateVersion = "26.05"; # Please read the comment before changing.
}
