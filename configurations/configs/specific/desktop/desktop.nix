{ config, pkgs, ... }:

{
  ### Import expression for desktop use
  imports = [
    ./x11.nix
    ./plymouth.nix
    ./portal.nix
    ./gnome-confinement.nix
  ];

  ### Option for desktop specific
  ### IBUS
  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      anthy
      hangul
      mozc
      libpinyin
    ];
  };
}
