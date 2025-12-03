{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Firefox
  programs.firefox = {
    enable = true;
    #enableHardening = true;
    wrapperConfig.pipewireSupport = true;
    languagePacks = [
      "fr"
      "en-US"
    ];
    preferences = {
      "intl.accept_languages" = "fr-fr,en-us,en";
      "intl.locale.requested" = "fr,en-US";
    };
  };
}
