{
  username,
  globalFeatures,
  userConfigs,
  userOverrides ? { },
  inputs,
  ...
}:

let
  entry = import ../entry.nix {
    inherit
      username
      globalFeatures
      userConfigs
      userOverrides
      inputs
      ;
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
