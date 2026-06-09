{ lib, config, ... }:

let
  cfg = config.marker;
  validValues = [
    "desktop"
    "server"
  ];
in
{
  ### Declare (blank) option
  options.marker.hostProfile = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum validValues);
    default = null;
    description = "Add a marker if it's a desktop or a server (for some action and specific option, does not effect, only for condition)";
  };

  config = {
    assertions = [
      {
        assertion = cfg != null;
        message = ''
          hostProfile must be set in your host configuration.
          Available values: ${lib.concatStringsSep ", " validValues}
        '';
      }
    ];
  };
}
