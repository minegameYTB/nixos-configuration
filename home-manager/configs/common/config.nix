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
 
}
