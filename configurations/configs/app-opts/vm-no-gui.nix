{ config, pkgs, ...  }:

{
 ### Programs with options
 ### htop
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

}
