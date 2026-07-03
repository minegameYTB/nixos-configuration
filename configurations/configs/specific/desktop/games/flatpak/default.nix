{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Add game-specific flatpaks only when GNOME is active
  services.flatpak.packages = lib.mkIf config.services.desktopManager.gnome.enable [
    "flathub:app/io.mrarm.mcpelauncher//stable"
    ":${./hytale-launcher-2026-06-27.flatpak}"
  ];
}
