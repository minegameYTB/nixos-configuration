{
  lib,
  config,
  pkgs,
  zen-browser,
  ...
}:

let
  ### By ABI (kernel type)
  isLinux = pkgs.stdenvNoCC.hostPlatform.isLinux;
  isDarwin = pkgs.stdenvNoCC.hostPlatform.isDarwin;

  ### By arch
  isX86_64 = pkgs.stdenvNoCC.hostPlatform.isx86_64;
  isAarch64 = pkgs.stdenvNoCC.hostPlatform.isAarch64;
in
{
  home.packages =
    ### All arch and all ABI (main pkgs)
    (with pkgs; [
      ### Add multi ABI packages here
    ])

    ### All arch and all ABI (pkgsUnstable)
    ++ (with pkgs.pkgsUnstable; [
      bitwarden-desktop
    ])

    ### x86_64-linux ABI (main pkgs)
    ++ lib.optionals (isX86_64 && isLinux) (
      with pkgs;
      [
        vlc
        tagainijisho
        discord
      ]
    )

    ### x86_64-linux ABI (pkgsUnstable)
    ++ lib.optionals (isX86_64 && isLinux) (
      with pkgs.pkgsUnstable;
      [
        deezer-enhanced
      ]
    )

    ### aarch64-linux ABI (main pkgs)
    ++ lib.optionals (isAarch64 && isLinux) (
      with pkgs;
      [
        legcord
      ]
    )

    ### aarch64-darwin ABI (main pkgs)
    ++ lib.optionals (isAarch64 && isDarwin) (
      with pkgs;
      [
        vlc-bin
        discord
      ]
    );
}
