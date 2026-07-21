{ globalFeatures, userConfigs, ... }:

let
  entry = import ../entry.nix {
    inherit globalFeatures userConfigs;
    username = "nixos";
    featPath = ../../../home-manager/features;
  };
in
entry
