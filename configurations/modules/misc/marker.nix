{ lib, ... }:

{
  ### Declare (blank) option
  options.deviceMarker = lib.mkOption {
    type = lib.types.enum [
      "desktop"
      "server"
    ];
    description = "Add a marker if it's a desktop or a server (for some action and specific option, does not effect, only for condition)";
  };
}
