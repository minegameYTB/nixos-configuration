{ config, pkgs, ...  }:

{
 ### Programs with options
 ### Firefox
 programs.firefox.enable = true;
  
 ### Steam
 programs.steam = {
   enable = true;
   extraCompatPackages = [
     pkgs.proton-ge-bin
   ];
 };

 ### gnu nano
 programs.nano.nanorc = ''
   set autoindent
   set linenumbers 
 '';

 ### NerdFonts
 fonts.packages = with pkgs; [
   (nerdfonts.override { fonts = [ "UbuntuMono" ]; })
 ];
 ### Replace actual syntax on 25.05 by:
 #fonts.packages = with pkgs; [ nerd-fonts.ubuntu-mono ];

}
