{
  globalFeatures,
  userConfigs,
  userOverrides ? { },
  inputs,
  ...
}:

let
  entry = import ../entry.nix {
    inherit globalFeatures userConfigs userOverrides inputs;
    username = "minegame";
    featPath = ../../../home-manager/features;
  };
in
entry
// {
  imports = entry.imports ++ [
    ./git.nix
    ./apps.nix
  ];
}
