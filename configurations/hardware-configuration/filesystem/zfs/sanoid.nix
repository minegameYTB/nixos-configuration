{ config, lib, ... }:

{
  services.sanoid = {
    enable = if (config.fileSystems."/".fsType == "zfs") then true else false;

    templates = {
      important-data = {
        hourly = 24;
        daily = 15;
        weekly = 4;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
    };

    datasets = {
      "zroot/USERDATA/home" = {
        use_template = [ "important-data" ];
      };
    };
  };

  ### Use system timezone (override upstream TZ=UTC)
  systemd.services.sanoid.environment.TZ = lib.mkForce config.time.timeZone;
}
