{ config, pkgs, ... }:

{
 ### Scheduling cpu cycle
 services.system76.scheduler.settings.cfsProfiles.enable = true;

 ### tlp services
 services.tlp = {
   enable = true;
   settings = {
     CPU_BOOST_ON_AC = 1
     CPU_BOOST_ON_BAT = 0;
     CPU_SCALING_GOVERNOR_ON_AC = "performance"
     CPU_SCALING_GOVERNOR_ON_BAT = "powersave"
   };
 };

 ### Disable Gnome power management
 services.power-profiles-daemon.enable = false

 ### Powertop
 powerManagement.powertop.enable = true;

 ### Thermald
 services.thermald.enable = true;
}
