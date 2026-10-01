{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;
    signing.format = "openpgp";
    ignores = [
      "*.swp"
      "*~"
    ];
    settings = {
      user.name = "Minegame YTB";
      user.email = "53137994+minegameYTB@users.noreply.github.com";
      credential.helper = "${config.programs.gh.package}/bin/gh auth setup-git";
      init = {
        defaultBranch = "main";
        rebase = true;
      };
      color.ui = true;
      core.hooksPath = ".githooks";
      # Skip stat-ing unchanged files: `git status` on nixpkgs drops ~1.7 s → ~0.5 s
      core.fsmonitor = true;
      fetch.prune = true;
    };
  };

  programs.gh = {
    enable = true;
    package = pkgs.pkgsUnstable.gh;
    settings.git_protocol = "https";
  };
}
