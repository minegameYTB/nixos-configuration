{ config, pkgsExtra, ... }:

{
 ### Add dolphin-emu
 environment.systemPackages = with pkgsExtra.pkgs-unstable; [ dolphin-emu ];

 ### custom settings for bluetooth device (udev rules)
 services.udev = {
   packages = [ pkgsExtra.pkgs-unstable.dolphin-emu ];
   extraRules = ''
     # Dolphin-emu Bluetooth
     # (HP probook)
     SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0a2a", TAG+="uaccess"
     
     # (HP 240)
     SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="b00b", TAG+="uaccess"
   '';
 };
}
