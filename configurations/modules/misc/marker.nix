{ lib, config, ... }:

let
  cfg = config.marker;
  validValues = [
    "desktop"
    "server"
  ];
  archValidValues = [
    # Default micro-arch
    "generic"
    "x86-64-v1"

    ### Other micro-arch
    "x86-64-v2"
    "x86-64-v3"
    "x86-64-v4"
    "amd-zen4"

    ### Arm64 arch
    "aarch64"
  ];
in
{
  ### Declare (blank) option
  options.marker = {
    hostProfile = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum validValues);
      default = null;
      description = "Add a marker if it's a desktop or a server (for some action and specific option, does not effect, only for condition)";
    };

    archProfile = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum archValidValues);
      default = null;
      description = "Add a marker for processor arch (for some action and specific option, does not effect, only for condition)";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.hostProfile != null;
        message = ''
          hostProfile must be set in your host configuration.
          Available values: ${lib.concatStringsSep ", " validValues}
        '';
      }
      {
        assertion = cfg.archProfile != null;
        message = ''
          archProfile must be set in your host configuration.
          Available values: ${lib.concatStringsSep ", " archValidValues}
        '';
      }
    ];
  };
}
