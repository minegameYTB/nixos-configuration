### Import pkgsExtra sets bcause it contain pkgs-unstable expression (installing fonts from nixpkgs unstable (at this time btw))
{ config, pkgs, pkgsExtra, ... }:

{
 ### Stylix config
 stylix = {
   enable = true;
   ### Accept fetchurl derivation (see stylix doc)
   image = ./wallpaper/tropic_island_morning.jpg;
  #image = pkgs.fetchurl {
  #  url = "";
  #  sha256 = "";
  #};
   polarity = "dark";
   fonts = {
     sansSerif = {
       ### Use pkgsExtra.pkgs-unstable to get adwaita-fonts (even if i use nixpkgs stable by default)
       package = pkgsExtra.pkgs-unstable.adwaita-fonts;
       name = "Adwaita Sans";
     };
     serif = {
       package = pkgsExtra.pkgs-unstable.adwaita-fonts;
       name = "Adwaita Sans";
     };
     monospace = {
       package = pkgsExtra.pkgs-unstable.adwaita-fonts;
       name = "Adwaita Mono";
     };
   };
  #base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
   cursor = {
     ### Use nixpkgs stable for this package
     package = pkgs.catppuccin-cursors.mochaDark;
     name = "catppuccin-mocha-dark-cursors";
     size = 24;
   };
 };
}
