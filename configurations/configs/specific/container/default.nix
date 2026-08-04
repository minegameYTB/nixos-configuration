{
  ### Per-machine container subsystems. Each subsystem activates only when
  ### its gate is enabled at the machine profile level:
  ###   containerSubsystems.nixos  -> nixos-container/ (declarative NixOS containers)
  ###   containerSubsystems.podman -> podman.nix
  ###   containerSubsystems.nspawn -> nspawn.nix
  ### Declarations stay inert when their gate is off, so importing this folder
  ### is safe on any machine (nothing activates without explicit opt-in).
  imports = [
    ./nixos-container
    ./podman.nix
    ./nspawn.nix
  ];
}
