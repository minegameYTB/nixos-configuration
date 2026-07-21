{ lib, config, pkgs, inputs, ... }:

{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    languagePacks = [
      "fr"
      "en-US"
    ];
    nativeMessagingHosts = [
      pkgs.firefoxpwa
    ];
    profiles = {
      default = {
        mods = [
          "906c6915-5677-48ff-9bfc-096a02a72379"
          "253a3a74-0cc4-47b7-8b82-996a64f030d5"
          "3ff55ba7-4690-4f74-96a8-9e4416685e4e"
        ];
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          sponsorblock
          privacy-badger
          pwas-for-firefox
        ];
        search = {
          force = true;
          default = "ddg";
          engines =
            let
              knownReleases = [ "25.11" "26.05" ];
              mm = lib.trivial.release;
              channelVersion = if builtins.elem mm knownReleases then mm else "unstable";
            in
            {
              nixosPkgSearch = {
                name = "NixOS Packages Search";
                urls = [{
                  template = "https://search.nixos.org/packages?channel=${channelVersion}&query={searchTerms}";
                }];
                icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = [ "@nx" ];
              };
              nixosOptSearch = {
                name = "NixOS Options Search";
                urls = [{
                  template = "https://search.nixos.org/options?channel=${channelVersion}&query={searchTerms}";
                }];
                icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = [ "@nxOpt" ];
              };
            };
        };
      };
    };
  };
}
