{ config, ... }:

{
  ### Import all expression to add games and settings related to gaming on this config
  imports = [
    ./steam
    #./lutris
    #./heroic
    ./prismlauncher
    ./waydroid
    ./emulator
  ];

  ### Specific settings for controller
  services.udev.extraRules = ''
    # USB
    ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  ''
  + (
    if (config.hardware.bluetooth.enable == true) then
      ''

        # Bluetooth
        ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
        ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ''
    else
      ""
  );
}
