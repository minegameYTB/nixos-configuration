{
  config,
  pkgs,
  inputs,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Molokai";
      background-opacity = 0.5;
      font-size = 10;
      background-blur = true;
      working-directory = "home";
      window-height = 35;
      window-width = 135;
      # alt+enter toggles fullscreen by default, which steals the key from
      # zsh (multiline insert). Unbind it.
      keybind = [ "alt+enter=unbind" ];
    };
  };

  xdg.configFile = {
    "fastfetch/config.jsonc".source = "${inputs.dotfiles-minegameYTB}/configs/fastfetch/config.jsonc";
    "opencode/opencode.jsonc".source = "${inputs.dotfiles-minegameYTB}/configs/opencode/opencode.jsonc";
  };
}
