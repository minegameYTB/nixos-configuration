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
  
 ## htop
 programs.htop = {
   enable = true;
   settings = {
     show_merged_command = true;
     show_cpu_frequency = true;
     show_cpu_temperature  = true;
   };
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

}
