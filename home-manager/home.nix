{ config, pkgs, ... }:

let
  ### Add external packages
 #sshrm = pkgs.callPackage ../pkgs/sshrm {};
in
{
  imports = [
    ./modules/common/cli-packages.nix
  ];

  home.username = "minegame";
  home.homeDirectory = "/home/minegame";

  home.stateVersion = "24.05"; # Please read the comment before changing.

  home.packages = with pkgs; [
    ### Theme
    adw-gtk3
    catppuccin-cursors.mochaDark

    ### non-free apps
    vesktop
    spotify

    ### Audio
    amberol

    ### Video
    vlc

    ### Office
    onlyoffice-bin

    ### Editor

    ### Games 
    prismlauncher

    ### Utilities
    rpi-imager
    gnome-extension-manager
    bottles
    bitwarden-desktop
  ];

  home.file = {
    ".themes".source = ./dotfiles/themes;
    ".icons".source = ./dotfiles/icons;
    ".screenrc".source = ./dotfiles/screenrc;
  };

  home.sessionVariables = {
    EDITOR = "nano";
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName  = "Minegame YTB";
    userEmail = "53137994+minegameYTB@users.noreply.github.com";
  };

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        padding = {
          top = 1;
        };
      };
      modules = [
        "separator"
        "datetime"
        "os"
        "locale"
        "shell"
        "host"
        "kernel"
        "uptime"
        "packages"
        "display"
        "de"
        "wm"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "battery"
        "poweradapter"
        "separator"
        "colors"
        "separator"
      ];
    };
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
      export NIXPKGS_COMMIT=$(jq -r '.nodes."nixpkgs".locked.rev' $HOME/nixos-configuration/flake.lock|cut -c1-8)
      #${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
    '';
  };
}
