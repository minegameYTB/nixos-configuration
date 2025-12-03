{ config, pkgs, ... }:

{
  ### Steam (already provide steam-run (unfree))
  programs.steam = {
    enable = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
  };
}
