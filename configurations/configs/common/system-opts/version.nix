{
  lib,
  config,
  pkgs,
  ...
}:

let
  repoUrl = (import ../../../../lib/repo.nix).url;
in
{
  ### custom /etc/os-release file (with system.nixos.extraOSReleaseArgs) (https://github.com/NixOS/nixpkgs/blob/28096cc5e3d8334fbe1845925f000f8c8c5e0aac/nixos/modules/misc/version.nix#L163)
  system.nixos.extraOSReleaseArgs = rec {
    CONFIG_URL = repoUrl;
    #BUG_REPORT_URL = CONFIG_URL + "/issues"; # To use concatened text with a variable

    ### Tests
    #NAME = "Minegame OS";
    #PRETTY_NAME = NAME + " " + lib.trivial.release + " " + "(${lib.trivial.codeName})";
  };
}
