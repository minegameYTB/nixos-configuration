{ config, pkgs, ... }:

{
  ### Localsend
  programs.localsend.enable = true;

  ### Tmux
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    clock24 = true;
    plugins = with pkgs; [
      tmuxPlugins.nord
    ];
  };

  ### xdg terminal exec
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [
        "ghostty.desktop"
      ];
    };
  };

  ### Neovim
  programs.neovim = {
    enable = true;
    viAlias = true;
    withPython3 = false;
    withRuby = false;
    configure = {
      customRC = ''
        colorscheme tokyonight-night
      '';
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          tokyonight-nvim
        ];
      };
    };
  };
}
