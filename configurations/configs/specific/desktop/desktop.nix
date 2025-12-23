{ config, pkgs, ... }:

{
  ### Import expression for desktop use
  imports = [
    ./x11.nix
    ./plymouth.nix
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

  ### Xdg portal
  xdg.portal.enable = true;
}
