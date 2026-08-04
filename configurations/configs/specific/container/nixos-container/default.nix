{
  ### NixOS containers subsystem (the containerSubsystems.nixos gate is
  ### declared in nixos-containers.nix). Container declarations stay inert
  ### when the gate is off, so importing this folder is safe anywhere.
  imports = [
    ./nixos-containers.nix
    ./opencode-sandbox
  ];
}
