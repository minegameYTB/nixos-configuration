{
  globalFeatures,
  userConfigs,
  userOverrides ? { },
  ...
}:

let
  entry = import ../entry.nix {
    inherit globalFeatures userConfigs userOverrides;
    username = "nixos";
    featPath = ../../../home-manager/features;
  };
in
entry
