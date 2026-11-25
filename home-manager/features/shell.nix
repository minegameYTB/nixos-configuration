{ config, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    ### Old custom PS1 prompt — replaced by starship (commented out):
    #initExtra = ''
    #  case "$TERM" in
    #    xterm-color|*-256color) color_prompt=yes;;
    #  esac
    #
    #  if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
    #    PROMPT_COLOR="1;31m"
    #    ((UID)) && PROMPT_COLOR="1;32m"
    #    if [ -n "$INSIDE_EMACS" ]; then
    #      PS1="\n\[\033[$PROMPT_COLOR\][\u@\h:\w]\\$\[\033[0m\] "
    #    else
    #      PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
    #    fi
    #    if test "$TERM" = "xterm"; then
    #      PS1="\[\033]2;\h:\u:\w\007\]$PS1"
    #    fi
    #  fi
    #'';
  };

  ### Prompt: starship config written to ~/.config/starship.toml — starship's
  ### default location, so both shells read the same config: zsh (init comes
  ### from configurations/configs/common/system-opts/shell.nix) and bash (init
  ### injected by this module into bash initExtra below the old commented PS1).
  programs.starship = {
    enable = true;
    presets = [ "tokyo-night" ];
    settings = {
      ### Real Nerd Font NixOS logo (U+F313, same glyph as starship's official
      ### nerd-font-symbols preset) instead of the default ❄️ emoji:
      os.symbols.NixOS = builtins.fromJSON ''"\uf313 "'';
      ### Directory: stock tokyo-night uses light grey text (#e3e5e5) on the
      ### bright blue (#769ff0) → only 2:1 contrast (barely readable "~").
      ### Dark text like the [os] segment instead → ~7.5:1.
      directory.style = "fg:#090c0c bg:#769ff0";
    };
  };

  programs.htop = {
    enable = true;
    settings = {
      show_merged_command = true;
      show_cpu_frequency = true;
      show_cpu_temperature = true;
      show_thread_names = true;
      highlight_base_name = true;
      screen_tabs = true;
      fields = with config.lib.htop.fields; [
        PID
        USER
        PRIORITY
        NICE
        M_SIZE
        M_RESIDENT
        M_SHARE
        STATE
        PERCENT_CPU
        PERCENT_MEM
        TIME
        COMM
      ];
    }
    // (
      with config.lib.htop;
      leftMeters [
        (bar "AllCPUs")
        (bar "Memory")
        (bar "Swap")
      ]
    )
    // (
      with config.lib.htop;
      rightMeters [
        (text "System")
        (text "Tasks")
        (text "LoadAverage")
        (text "Uptime")
      ]
    );
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    clock24 = true;
    plugins = with pkgs; [ tmuxPlugins.nord ];
  };

  programs.nix-index.enable = true;
}
