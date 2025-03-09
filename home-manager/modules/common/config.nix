{ config, pkgs, ... }:

{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

#home.sessionVariables = {
#  EDITOR = "nvim";
#};

 programs.home-manager.enable = true;

 programs.git = {
   enable = true;
   userName  = "Minegame YTB";
   userEmail = "53137994+minegameYTB@users.noreply.github.com";
 };

 programs.gh = {
   enable = true;
   settings = {
     git_protocol = "https";
   };
 };

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

 programs.zsh = {
   enable = true;
   syntaxHighlighting = {
     enable = true;
   };
   autosuggestion = {
     enable = true;
     strategy = [ "match_prev_cmd" ];
   };
   initExtra = ''
     export NIXPKGS_COMMIT=$(curl -s https://raw.githubusercontent.com/minegameYTB/nixos-configuration/flake/flake.lock | jq -r '.nodes."nixpkgs".locked.rev' | cut -c1-8)
     #${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
   '';
 };
 
}
