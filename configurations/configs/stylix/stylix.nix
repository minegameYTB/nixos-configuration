{ config, pkgs, ... }:

{
 ### Stylix config
 stylix = {
   enable = true;
   ### Accept fetchurl derivation (see stylix doc)
   image = pkgs.fetchurl {
     url = "https://raw.githubusercontent.com/ChapST1/gruvbox-wallpapers-web/master/wallpapers/pixelart/9.png";
     sha256 = "sha256-lfZ2g+DzBmQj8yHGmW1laDnhTEQtwvL75Dv9LLHgEQM=";
   };
   polarity = "dark";
   cursor = {
     package = pkgs.catppuccin-cursors.mochaDark;
     name = "catppuccin-mocha-dark-cursors";
   };
 };
}
