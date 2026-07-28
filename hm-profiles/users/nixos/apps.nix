{
  config,
  pkgs,
  inputs,
  ...
}:

{
  xdg.configFile = {
    "ghostty/config".source = "${inputs.dotfiles-minegameYTB}/configs/ghostty/config";
    "fastfetch/config.jsonc".source = "${inputs.dotfiles-minegameYTB}/configs/fastfetch/config.jsonc";
    "opencode/opencode.jsonc".source = "${inputs.dotfiles-minegameYTB}/configs/opencode/opencode.jsonc";
  };
}
