{
  lib,
  pkgs,
  config,
  keyboardSetupScript,
  welcomeMessage,
  rev,
  branch,
  edition,
  mkIsoConfig,
  ...
}:
{
  imports = [
    (mkIsoConfig {
      inherit
        edition
        rev
        branch
        welcomeMessage
        keyboardSetupScript
        ;
    })
  ];

  marker = {
    hostProfile = "server";
    archProfile = "x86-64-v1";
  };

  console.keyMap = "fr";
}
