{ config, ... }:

{
 ### tlp
 services.power-profiles-daemon.enable = false;
 services.tlp = {
   enable = true;
   settings = {
     CPU_SCALING_GOVERNOR_ON_AC = "performance";
     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
 
    #Optional helps save long term battery health
     START_CHARGE_THRESH_BAT0 = 40; # 40 and bellow it starts to charge
     STOP_CHARGE_THRESH_BAT0 = 90; # 80 and above it stops charging
   };
 }; 

}
