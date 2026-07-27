{ config, ... }:

{
  services.sanoid = {
    enable = true;

    templates = {
      important-data = {
        hourly = 24;
        daily = 14;
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
}
