{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import nix-flatpak (for games this time, even if this is enable by default)
  imports = [ inputs.declarative-flatpak.nixosModules.default ];

  ### Declarative flatpak settings
  services.flatpak = {
    enable = true;
    remotes = {
      "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
    };
    packages = [
      ### Argument order (to see commit, do "flatpak info software")
      ### Search package with this command (for all used info)
      # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]

      ":${./hytale-launcher-2026-01-24.flatpak}"
      #"flathub:app/it.mq1.TinyWiiBackupManager//stable"
      #"com.usebottles.bottles"
    ];
  };
}
