{
  globalFeatures,
  userConfigs,
  userOverrides ? { },
  inputs,
  ...
}:

let
  entry = import ../entry.nix {
    inherit
      globalFeatures
      userConfigs
      userOverrides
      inputs
      ;
    username = "nixos";
    featPath = ../../../home-manager/features;
  };
in
entry
// {
  imports = entry.imports ++ [
    ./apps.nix
  ];
}
