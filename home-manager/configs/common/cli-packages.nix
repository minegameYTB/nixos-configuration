{ config, pkgs, ... }:

{
  home.packages = with pkgs; [

    ### Utilities
    jq
    dhall-json
    ripgrep
    fastfetch

    ### Installed for manpages (used as aliases)
    bat
    lsd
    duf
  ];

}
