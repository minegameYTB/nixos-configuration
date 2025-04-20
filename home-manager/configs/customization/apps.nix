{ config, pkgs, inputs, ... }:

{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 ### Install theme on home directory
 xdg.configFile = {
   ### Ghostty
   "ghostty/config".source = "${inputs.dotfiles-minegameYTB}/configs/ghostty/config";
 };

}
