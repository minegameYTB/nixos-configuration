{
  username,
  globalFeatures,
  userConfigs,
  userOverrides ? { },
  inputs,
  withStylix ? true,
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
      withStylix
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
