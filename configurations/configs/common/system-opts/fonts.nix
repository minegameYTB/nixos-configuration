{ config, pkgs, ... }:

{
 ### NerdFonts
 #fonts.packages = with pkgs; [
 #  (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
 #];
 
 ### Replace actual syntax on 25.05 by:
 #fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
}
