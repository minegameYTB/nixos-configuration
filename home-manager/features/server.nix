{ lib, config, pkgs, inputs, ... }:

{
  targets.genericLinux.enable = true;

  nixpkgs.overlays = [ inputs.nur.overlays.default ];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 15d";
    };
  };

  home.sessionVariables = {
    PATH = "$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH";
  };

  home.shellAliases = {
    nix = "nix --refresh --cores 2";
    home-manager = "home-manager -b bak";
    gadd = "git add";
    gpush = "git push";
    gpull = "git pull";
    gc = "git commit";
    gsw = "git switch";
    gbr = "git branch";
    gft = "git fetch";
    ls = "${pkgs.lsd}/bin/lsd";
    cat = "${pkgs.bat}/bin/bat";
    df = "${pkgs.duf}/bin/duf -hide special";
    "ls.ori" = "${pkgs.coreutils}/bin/ls";
    "cat.ori" = "${pkgs.coreutils}/bin/cat";
    "df.ori" = "${pkgs.coreutils}/bin/df";
    rm = "${pkgs.coreutils}/bin/rm --interactive=never";
    ssh = "TERM=xterm-256color ssh";
    open = "${pkgs.xdg-utils}/bin/xdg-open";
  };

  home.packages = with pkgs; [ nix ];

  home.activation = {
    report-changes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      report-changes(){
        export PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin"
        echo -e "\n===================================="
        echo      "| Running nvd diff to show changes |"
        echo -e   "====================================\n"
        nvd diff $oldGenPath $newGenPath
        echo ""
      }
      report-changes
    '';
  };
}
