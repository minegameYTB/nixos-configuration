{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    signing.format = "openpgp";
    ignores = [
      "*.swp"
      "*~"
    ];
    settings = {
      user.name = "Minegame YTB";
      user.email = "53137994+minegameYTB@users.noreply.github.com";
      credential.helper = "/etc/profiles/per-user/minegame/bin/gh auth setup-git";
      init = {
        defaultBranch = "main";
        rebase = true;
      };
      color.ui = true;
      core.hooksPath = ".githooks";
    };
  };

  programs.gh = {
    enable = true;
    package = pkgs.pkgsUnstable.gh;
    settings.git_protocol = "https";
  };
}
