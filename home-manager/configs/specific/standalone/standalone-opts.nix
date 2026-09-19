{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Better integration of home manager in standalone mode
  targets.genericLinux.enable = true;

  ### Install the home-manager command (binary + completions) in the user
  ### profile so the `home-manager` shell alias below actually resolves.
  ### Then `home-manager switch` replaces the `nix run <branch> -- switch`
  ### used during the first install.
  programs.home-manager.enable = true;

  ### Nix settings, NUR overlay, nix package and nvd diff hook
  ### (single source of truth, mirrors NixOS-side nix-settings.nix)
  imports = [ ./nix-settings.nix ];

  ### Environment variable
  home.sessionVariables = {
    PATH = "$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH";
  };

  home.shellAliases = {
    ### Aliases
    nix = "nix --refresh --cores 2";
    home-manager = "home-manager -b bak";

    ### Git alias
    gadd = "git add";
    gpush = "git push";
    gpull = "git pull";
    gc = "git commit";
    gsw = "git switch";
    gbr = "git branch";
    gft = "git fetch";
    glog = "git log";

    ### Core utilities replacement
    ls = "${pkgs.lsd}/bin/lsd";
    cat = "${pkgs.bat}/bin/bat";
    df = "${pkgs.duf}/bin/duf -hide special";

    ### Original core utilities (from nixpkgs)
    "ls.ori" = "${pkgs.coreutils}/bin/ls";
    "cat.ori" = "${pkgs.coreutils}/bin/cat";
    "df.ori" = "${pkgs.coreutils}/bin/df";

    ### Rm never interact
    rm = "${pkgs.coreutils}/bin/rm --interactive=never";

    ### Use xterm-256color on runtime command
    ssh = "TERM=xterm-256color ssh";

    ### This alias is just inspired from macOS "open" command
    open = "${pkgs.xdg-utils}/bin/xdg-open";
  };
}
