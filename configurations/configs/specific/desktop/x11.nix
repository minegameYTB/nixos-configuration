{ config, pkgs, ... }:

{
  # Enable the X11 windowing system.
  services.xserver.enable = config.services.desktopManager.gnome.enable;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  ### Exclude Xterm
  services.xserver.excludePackages = with pkgs; [
    xterm
  ];

  ### Mesa
  hardware.graphics = {
    enable = true;

    ### Enable 32-bit platform
    enable32Bit = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  ### Enable kmscon in x11
  services.kmscon = {
    enable = true;
    useXkbConfig = true;
    fonts = [
      {
        name = "JetBrainsMono Nerd Font";
        package = pkgs.nerd-fonts.jetbrains-mono;
      }
    ];
  };
}
