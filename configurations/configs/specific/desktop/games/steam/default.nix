{
  config,
  pkgs,
  ...
}:

{
  ### Steam (already provide steam-run (unfree))
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraLibraries =
        # variable can be nammed with other name
        lib: with lib; [
          SDL2
        ];
    };
    extraCompatPackages = [
      pkgs.pkgs-unstable.proton-ge-bin
    ];
  };
}
