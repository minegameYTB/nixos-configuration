{ lib, config, pkgs, ... }:

let
  isX86_64 = pkgs.stdenvNoCC.hostPlatform.isx86_64;
  isAarch64 = pkgs.stdenvNoCC.hostPlatform.isAarch64;
in

{
  home.packages =
    (with pkgs; [
      vlc
      amberol
      pika-backup
      warp
    ])
    ++ (with pkgs.pkgsUnstable; [
    ])
    ++ lib.optionals isX86_64 (
      (with pkgs; [
        discord
      ])
      ++ (with pkgs.pkgsUnstable; [
        deezer-enhanced
      ])
    )
    ++ lib.optionals isAarch64 (
      with pkgs; [
        legcord
      ]
    );
}
