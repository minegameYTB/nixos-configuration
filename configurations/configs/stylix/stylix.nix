{ config, pkgs, ... }:

{
 ### Stylix config
 stylix = {
   enable = true;
   ### Accept fetchurl derivation (see stylix doc)
   image = ./wallpaper/firewatch.jpg;
   polarity = "dark";
   cursor = {
     package = pkgs.catppuccin-cursors.mochaDark;
     name = "catppuccin-mocha-dark-cursors";
   };
 };
}
