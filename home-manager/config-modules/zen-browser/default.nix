{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    # or inputs.zen-browser.homeModules.twilight
    # or inputs.zen-browser.homeModules.twilight-official
  ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    languagePacks = [
      "fr"
      "en-US"
    ];
    policies.preferences = {
      "intl.accept_languages" = {
        Value = "fr-fr,en-us,en";
      };
      "intl.locale.requested" = {
        Value = "fr,en-US";
      };
    };
    nativeMessagingHosts = [
      pkgs.firefoxpwa
    ];
    profiles = {
      default.search = {
        force = true; # Enforce declared search engines on each rebuild
        default = "ddg";
        engines = {
          mynixos = {
            name = "NixOS Search";
            urls =
              let
                knownReleases = [
                  "25.11"
                  "26.05"
                ];
                mm = lib.versions.majorMinor lib.version;

                # If not found, fallback to "unstable" value on url
                channelVersion = if builtins.elem mm knownReleases then mm else "unstable";
              in
              [
                {
                  template = "https://search.nixos.org/packages?channel=${channelVersion}&query={searchTerms}";
                }
              ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@nx" ];
          };
          ### Other search engine here ↓
        };
      };
    };
  };
}
