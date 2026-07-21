{ lib, config, pkgs, ... }:

let
  isX86_64 = pkgs.stdenvNoCC.hostPlatform.isx86_64;
in

{
  home.packages =
    (with pkgs; [
      prismlauncher
    ])
    ++ lib.optionals isX86_64 (
      with pkgs; [
        heroic
        lutris
        waydroid
      ]
    );
}
