{ config, ... }:

{
 ### NerdFonts
 fonts.packages = with pkgs; [
   (nerdfonts.override { fonts = [ "UbuntuMono" ]; })
 ];
 
 ### Replace actual syntax on 25.05 by:
 #fonts.packages = with pkgs; [ nerd-fonts.ubuntu-mono ];
}
