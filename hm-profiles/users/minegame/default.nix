{ globalFeatures, userConfigs, ... }:

let
  entry = import ../entry.nix {
    inherit globalFeatures userConfigs;
    username = "minegame";
    featPath = ../../../home-manager/features;
  };
in
entry // {
  imports = entry.imports ++ [
    ./git.nix
    ./apps.nix
  ];
}
