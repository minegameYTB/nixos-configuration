{ config, pkgs, ... }:

{
  stylix.targets = {
    ghostty.enable = true;
    gtk.flatpakSupport.enable = true;
  };
}
