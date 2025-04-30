{ config, pkgs, inputs, ... }:

{
 ### Install theme on home directory
 xdg.configFile = {
   ### Ghostty
   "ghostty/config".source = "${inputs.dotfiles-minegameYTB}/configs/ghostty/config";
 };
 
 ### stylix
 stylix = {
   enable = true;
   image = "${inputs.catppuccin-wallpapers}/landscapes/tropic_island_morning.jpg";
   targets = {
     tmux.enable = false;
   };
 };
 
}
