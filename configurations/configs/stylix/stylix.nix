{ config, pkgs, ... }:

{
 ### Stylix config
 stylix = {
   enable = true;
   ### Accept fetchurl derivation (see stylix doc)
   image = ./wallpaper/Cherish.png;
 };
}
