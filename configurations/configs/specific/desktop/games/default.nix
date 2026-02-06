{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Import all expression to add games and settings related to gaming on this config
  imports = [
    ./steam
    #./lutris
    #./heroic
    ./prismlauncher
    ./waydroid
    ./emulator
    ./other # Desktop games (not emulator or launcher)
    ./flatpak
  ];

  ### Add specific configuration
  boot = {
    # Enable ntsync
    kernelModules =
      if lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.18.0" then [ "ntsync" ] else [ ];
    kernel.sysctl = {
      "kernel.split_lock_mitigate" = 0;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_bytes" = 268435456;
      "vm.max_map_count" = 16777216;
      "vm.dirty_background_bytes" = 67108864;
      "vm.dirty_writeback_centisecs" = 1500;
    };
  };
  ### Mesa
  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-gpu-tools
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      libva
      vulkan-loader
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-gpu-tools
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      libva
    ];
  };

  ### Specific settings for controller
  services.udev.extraRules = ''
    # USB
    ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  ''
  + (
    if config.hardware.bluetooth.enable then
      ''

        # Bluetooth
        ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
        ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ''
    else
      ""
  );
  hardware.xone.enable = true;
}
