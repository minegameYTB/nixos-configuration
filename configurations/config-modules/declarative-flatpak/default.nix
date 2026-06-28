### Global flatpak configuration (for system and not home-manager)
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import nix-flatpak like an expression
  imports = [ inputs.declarative-flatpak.nixosModules.default ];

  ### Declarative flatpak settings (add condition for some settings if games/flatpak is enable)
  services.flatpak = {
    enable = lib.mkDefault true;
    remotes = lib.mkDefault {
      "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
    };
    packages = [
      ### Argument order (to see commit, do "flatpak info software")
      ### Search package with this command (for all used info)
      # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]

      "flathub:app/io.github.shiftey.Desktop//stable"
      "flathub:app/it.mijorus.gearlever//stable"
      #"flathub:app/it.mq1.TinyWiiBackupManager//stable"
      #"com.usebottles.bottles"
    ];
  };
}
