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

 ### Localsend
 programs.localsend.enable = true;

 ### gnu nano
 programs.nano = {
   ### Disable nano to use neovim instead (move this settings to a another file to use this settings...)
   enable = false;
   nanorc = ''
     set autoindent
     set linenumbers 
   '';
 };

 ### NerdFonts
 fonts.packages = with pkgs; [ nerd-fonts.ubuntu-mono ];

}
