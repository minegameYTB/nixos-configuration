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
  username,
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
        username
        ;
    })
  ];

  marker = {
    hostProfile = "server";
    archProfile = "x86-64-v1";
  };

  console.keyMap = "fr";
}
