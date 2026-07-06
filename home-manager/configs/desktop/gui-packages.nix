{
  lib,
  config,
  pkgs,
  zen-browser,
  ...
}:

let
  isX86_64 = pkgs.stdenvNoCC.hostPlatform.isx86_64;
  isAarch64 = pkgs.stdenvNoCC.hostPlatform.isAarch64;
in
{
  home.packages =
    ### All architectures (stable)
    (with pkgs; [
      vlc
      amberol
      pika-backup
      warp
      #libreoffice-fresh
      #hunspellDicts.fr-any
    ])
    ### All architectures (unstable)
    ++ (with pkgs.pkgsUnstable; [
      bitwarden-desktop
      #rpi-imager
    ])
    ### x86_64 only
    ++ lib.optionals isX86_64 (
      (with pkgs; [
        discord
        #spotify
      ])
      ++ (with pkgs.pkgsUnstable; [
        deezer-enhanced
      ])
      ### disable in flake.nix for the moment
      #++ (with pkgs.pkgsPr; [
      #  claude-desktop
      #])
      #++ (with pkgs.pkgsMaster; [
      #  deezer-enhanced
      #])
    )
    ### aarch64 only
    ++ lib.optionals isAarch64 (
      with pkgs;
      [
        legcord
      ]
    );
}
