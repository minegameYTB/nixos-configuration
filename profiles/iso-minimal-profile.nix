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
    ../configurations/configuration.nix

    ### Networking
    ../configurations/configs/networking

    ### Config modules (stylix, flatpak, nix-index-db)
    ../configurations/config-modules

    ### Tmpfs /tmp
    ../configurations/configs/system/tmp-on-tmpfs.nix

    ### Shared ISO config (naming, keyboard, services, etc.)
    (mkIsoConfig { inherit edition rev branch welcomeMessage keyboardSetupScript; })
  ];

  ### marker: server profile → uses cachyos LTS kernel
  marker = {
    hostProfile = "server";
    archProfile = "x86-64-v1";
  };

  ### Default keyboard — French (fr)
  console.keyMap = "fr";
}
