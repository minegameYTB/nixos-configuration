{
  globalFeatures = [
    "cli"
    "shell"
    "shell-no-zsh-hm"
    "desktop-core"
  ];

  users = {
    minegame = {
      description = "Minegame YTB";
      username = "minegame";
      hmFeatures = [
        "development"
        "gnome"
        "games"
        "browser"
        "multimedia"
        "customization"
      ];
    };
  };
}
