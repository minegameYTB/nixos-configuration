{ ... }: {
  home.stateVersion = "26.05";

  ### Each sub-directory wraps an external flake module (lazyvim, zen-browser).
  ### Activation is handled individually by home-manager/features/<name>.nix
  ### via (inputs.self + "/home-manager/config-modules/<name>").
}
