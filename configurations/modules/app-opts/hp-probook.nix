{ config, pkgs, ...  }:

{
 ### Programs with options
 programs = {
   firefox.enable = true;
   gamemode = {
     enable = true;
   };
   nano.nanorc = ''
     set autoindent
     set linenumbers
   '';
  };

 fonts.packages = with pkgs; [
   (nerdfonts.override { fonts = [ "UbuntuMono" ]; })
 ];
 ### Replace actual syntax on 25.05 by:
 #fonts.packages = with pkgs; [ nerd-fonts.ubuntu-mono ];

}
