{ config, pkgs, ... }:

{
  ### Import expression for desktop use
  imports = [
    ./x11.nix
    ./plymouth.nix
    ./portal.nix
    ./gnome-confinement.nix
    ./host-confinement.nix
  ];

  ### Option for desktop specific
  ### IBUS
  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      anthy
      hangul
      # TODO(mozc): disabled temporarily — mozc 2.30.5544.102 fails to build at
      # nixpkgs 02c087f (uic rejects the ::-scoped class name in dictionary_tool.ui),
      # fixed by nixpkgs PR #531687 (merged 2026-10-21, blocked in nixos-unstable
      # until Hydra rolls past the broken revision). Re-enable once it lands.
      #mozc
      libpinyin
    ];
  };
}
