{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  ### Git
  programs.git = {
    enable = true;
    ignores = [
      "*.swp"
      "*~"
    ];
    settings = {
      user.name = "Minegame YTB";
      user.email = "53137994+minegameYTB@users.noreply.github.com";
      credential = {
        ### Use gh from profile
        helper = "/etc/profiles/per-user/minegame/bin/gh auth setup-git";
      };
      init = {
        defaultBranch = "main";
        rebase = true;
      };
      color.ui = true;
    };
  };

  ### GH
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
    };
  };

  ### Htop
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

  ### Tmux
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    clock24 = true;
    plugins = with pkgs; [
      tmuxPlugins.nord
    ];
  };

  ### bash
  programs.bash = {
    enable = true;
    initExtra = ''
      ### Color in tab
      case "$TERM" in
        xterm-color|*-256color) color_prompt=yes;;
      esac


      # Provide a nice prompt if the terminal supports it.
      if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
        PROMPT_COLOR="1;31m"
        ((UID)) && PROMPT_COLOR="1;32m"
        if [ -n "$INSIDE_EMACS" ]; then
          # Emacs term mode doesn't support xterm title escape sequence (\e]0;)
          PS1="\n\[\033[$PROMPT_COLOR\][\u@\h:\w]\\$\[\033[0m\] "
        else
          PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
        fi
        if test "$TERM" = "xterm"; then
          PS1="\[\033]2;\h:\u:\w\007\]$PS1"
        fi
      fi
    '';
  };

  ### Prevent zsh to show question for .zshrc
  home.file.".zshrc".text =
    "### this file is here to prevent zsh to show question regarding this file.";

  ### Fonts
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-cjk-sans
  ];
  fonts.fontconfig.enable = true;
}
