{ config, pkgsExtra, ... }:

{
  ### Steam (already provide steam-run (unfree))
  programs.steam = {
    enable = true;
    extraCompatPackages = [
      pkgsExtra.pkgs-unstable.proton-ge-bin
    ];
  };
}
