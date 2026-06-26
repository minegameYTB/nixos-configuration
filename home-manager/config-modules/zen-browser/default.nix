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
      default = {
        mods = [
          "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
          "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
          "3ff55ba7-4690-4f74-96a8-9e4416685e4e" # Colored container tab
        ];
        extensions.packages =
          let
            firefox-addons = pkgs.nur.repos.rycee.firefox-addons;
          in
          with firefox-addons;
          [
            ublock-origin
            sponsorblock
            privacy-badger
            pwas-for-firefox
          ];
        search = {
          force = true; # Enforce declared search engines on each rebuild
          default = "ddg";
          engines =
            let
              knownReleases = [
                "25.11"
                "26.05"
              ];

              # lib.trivial.release returns the current nixpkgs release as "YY.MM"
              # e.g. "25.11" on both stable and unstable tracking that release
              mm = lib.trivial.release;

              # If the release is not in the known list, fall back to "unstable"
              channelVersion = if builtins.elem mm knownReleases then mm else "unstable";
            in
            {
              nixosPkgSearch = {
                name = "NixOS Packages Search";
                urls = [
                  {
                    template = "https://search.nixos.org/packages?channel=${channelVersion}&query={searchTerms}";
                  }
                ];
                icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = [ "@nx" ];
              };
              nixosOptSearch = {
                name = "NixOS Options Search";
                urls = [
                  {
                    template = "https://search.nixos.org/options?channel=${channelVersion}&query={searchTerms}";
                  }
                ];
                icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = [ "@nxOpt" ];
              };
              ### Other search engine here ↓
            };
        };
      };
    };
  };
}
