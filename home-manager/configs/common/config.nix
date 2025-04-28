{ config, pkgs, ... }:

{
 programs.home-manager.enable = true;

 ### Nix option
 nix = {
   gc = {
     automatic = true;
     frequency = "weekly";
     options = "--delete-older-than 7d";
   };
 };

 ### Git
 programs.git = {
   enable = true;
   userName  = "Minegame YTB";
   userEmail = "53137994+minegameYTB@users.noreply.github.com";
   ignores = [
     "*.swp"
     "*~"
   ];
   extraConfig = {
     credential = {
       ### Use gh from profile
       helper = "/etc/profiles/per-user/minegame/bin/gh auth setup-git";
     };
     init.defaultBranch = "main";
     push.autoSetupRemote = true;
   };
 };

 ### Aliases
 home.shellAliases = {
   ff = "fastfetch";
   ls = "ls --color=auto";
   nix = "nix -v --refresh";
   gc = "git commit";
   gadd = "git add";
   gpush = "git push";
   gpull = "git pull";

   ### This alias is just inspired from macOS "open" command
   open = "xdg-open";
 };

 ### GH
 programs.gh = {
   enable = true;
   settings = {
     git_protocol = "https";
   };
 };

 ### Fastfetch
 programs.fastfetch = {
   enable = true;
#  settings = {
#    logo = {
#      padding = {
#       top = 1;
#      };
#    };
#    modules = [
#      "separator"
#      "datetime"
#      "os"
#      "locale"
#      "shell"
#      "host"
#      "kernel"
#      "uptime"
#      "packages"
#      "display"
#      "de"
#      "wm"
#      "cpu"
#      "gpu"
#      "memory"
#      "swap"
#      "battery"
#      "poweradapter"
#      "separator"
#      "colors"
#      "separator"
#    ];
#  };
 };
  
 ### Htop
 programs.htop = {
   enable = true;
   settings = {
     show_merged_command = true;
     show_cpu_frequency = true;
     show_cpu_temperature  = true;
     show_thread_names = true;
     highlight_base_name = true;
     screen_tabs = true;
   };
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

 ### zsh
 programs.zsh = {
   enable = true;
   syntaxHighlighting = {
     enable = true;
     highlighters = [
       "main"
     ];
     styles = {
       "comment" = "fg=red,bold";
       "unknown-token" = "fg=red";
     };
   };
   autosuggestion = {
     enable = true;
     strategy = [ "match_prev_cmd" ];
   };
   oh-my-zsh = {
     enable = true;
     theme = "agnoster";
   };
   ### Replace initExtra by InitContent (after upgrade to home-manager/nixos-25.05)
   initExtra = ''
     export NIXPKGS_COMMIT=$(curl -s https://raw.githubusercontent.com/minegameYTB/nixos-configuration/flake/flake.lock | jq -r '.nodes."nixpkgs".locked.rev' | cut -c1-8)
   '';
 };

 ### Fonts
 home.packages = with pkgs; [
 
 ### Replace actual syntax on 25.05 by:
 # nerd-fonts.jetbrains-mono
   (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
 ];
}
