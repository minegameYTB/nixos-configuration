{ config, pkgs, ... }:

{
  ### Add other games
  environment.systemPackages = with pkgs.pkgsUnstable; [
    # Need to import manually game rom with "nix-store --add-fixed sha256 <File>" command (if not, build error)
    (sm64coopdx.overrideAttrs (oldAttrs: rec {
      version = "1.4.1";

      src = fetchFromGitHub {
        owner = "coop-deluxe";
        repo = "sm64coopdx";
        rev = "v${version}";
        hash = "sha256-ct7X6LCitk1QID00guvYOMfIwnZccMeXqXwUB3ioKh8=";
      };
    }))
  ];
}
