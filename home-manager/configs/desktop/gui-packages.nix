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
    ### All arch
    (with pkgs; [
      vlc
      tagainijisho

      ### Libreoffice (and langpack)
      #libreoffice-fresh
      #hunspellDicts.fr-any
    ])
    ### All arch (pkgs from unstable branch)
    ++ (with pkgs.pkgs-unstable; [
      bitwarden-desktop
    ])
    ### Packages specific to x86_64-linux (main pkgs branch)
    ++ lib.optionals isX86_64 (
      with pkgs;
      [
        discord
        spotify
      ]
    )
    ### Packages specific to aarch64-linux (main pkgs branch)
    ++ lib.optionals isAarch64 (
      with pkgs;
      [
        legcord
      ]
    )
    ### Packages from pkgs-unstable for x86_64-linux only
    ++ lib.optionals isX86_64 (
      with pkgs.pkgs-unstable;
      [
        ### unstable pkgs here
        deezer-enhanced
      ]
    )
    ### Packages from pkgs-unstable for aarch64-linux
    ++ lib.optionals isAarch64 (
      with pkgs.pkgs-unstable;
      [
        ### unstable pkgs here
      ]
    );
  ### disable in flake.nix for the moment
  #++ lib.optionals isX86_64 (with pkgs.pkgs-pr; [
  ### Temporairy add pkgs-pr repo here
  #deezer-enhanced
  #])
  #++ lib.optionals isX86_64 (with pkgs.pkgs-master; [
  #  deezer-enhanced
  #]);
}
