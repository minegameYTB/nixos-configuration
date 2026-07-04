{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Steam (already provide steam-run (unfree)) (x86_64 only)
  programs.steam = lib.mkIf pkgs.stdenvNoCC.hostPlatform.isx86_64 {
    enable = true;
    package = pkgs.steam.override {
      extraLibraries =
        # variable can be nammed with other name
        lib: with lib; [
          SDL2
        ];
    };
    extraCompatPackages = with pkgs; [
      pkgsUnstable.proton-ge-bin
      proton-cachyos-bin # GLF-OS apps
    ];
  };
}
