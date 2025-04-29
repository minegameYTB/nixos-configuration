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
   targets = {
     tmux.enable = false;
   };
 };
 
}
