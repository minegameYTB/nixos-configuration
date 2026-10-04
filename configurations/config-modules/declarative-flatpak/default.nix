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

  ### Declarative flatpak settings (only enable when GNOME is active)
  services.flatpak = lib.mkIf config.services.desktopManager.gnome.enable {
    enable = true;
    # v4.2+ default: manage flatpaks on graphical.target (all our packages
    # are GUI apps on GNOME machines). Set explicitly to silence the
    # upstream builtins.trace nagging on every evaluation.
    runWithoutGui = false;
    remotes = {
      "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
    };
    packages = [
      "flathub:app/io.github.shiftey.Desktop//stable"
      "flathub:app/it.mijorus.gearlever//stable"
      "flathub:app/com.github.tchx84.Flatseal//stable"
      #"flathub:app/io.github.qwersyk.Newelle//stable"
      #"flathub:app/it.mq1.TinyWiiBackupManager//stable"
    ];
  };
}
