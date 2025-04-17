{ config, pkgs, ... }:

{
 ### Stylix config
 stylix = {
   enable = true;
   ### Accept fetchurl derivation (see stylix doc)
   image = ./wallpaper/Cherish.png;
  #image = pkgs.fetchurl {
  #  url = "";
  #  sha256 = "";
  #};
   polarity = "dark";
  #base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
   cursor = {
     package = pkgs.catppuccin-cursors.mochaDark;
     name = "catppuccin-mocha-dark-cursors";
   };
 };
}
