{ config, properties, ... }:

{
  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties. (change properties.[...] value in flake.nix
  i18n = {
    defaultLocale = properties.i18n;
    extraLocaleSettings = {
      LC_ADDRESS = properties.i18n;
      LC_IDENTIFICATION = properties.i18n;
      LC_MEASUREMENT = properties.i18n;
      LC_MONETARY = properties.i18n;
      LC_NAME = properties.i18n;
      LC_NUMERIC = properties.i18n;
      LC_PAPER = properties.i18n;
      LC_TELEPHONE = properties.i18n;
      LC_TIME = properties.i18n;
    };
  };

  # Configure console keymap
  console.keyMap = properties.keyMap;
}
