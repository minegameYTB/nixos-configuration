{
  config,
  pkgs,
  pkgsExtra,
  inputs,
  ...
}:

{
  ### Import conf file for cli software
  home.file = {
    #".screenrc".source = "${inputs.dotfiles-minegameYTB}/configs/screen/screenrc";
  };

  xdg.configFile = {
    "fastfetch/config.jsonc".source = "${inputs.dotfiles-minegameYTB}/configs/fastfetch/config.jsonc";
  };
}
