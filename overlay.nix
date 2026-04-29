{
  lib,
  system,
  inputs,
  nixpkgsConfig,
  ...
}:

### autocomplete with inputs in early step here to avoid repeat "inputs.[...].args"
with inputs;
{
  nixpkgs.overlays = [
    ### Custom extend of pkgs or replacing pkgs by other
    (self: super: rec {
      ### Extend pkgs with nur namespace
      nur = import inputs.nur {
        nurpkgs = pkgsUnstable;
        pkgs = pkgsUnstable;
      };

      ### Extend pkgs namespace here
      # inject pkgs-<release> in pkgs namespace instead of pkgsExtra variable
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config = nixpkgsConfig;
        overlays = [ ];
      };
      #pkgsLts = import ctrl-os {
      #  inherit system;
      #  config = nixpkgsConfig;
      #};
      #pkgsMaster = import nixpkgs-master {
      #  inherit system;
      #  config = nixpkgsConfig;
      #};
      #pkgsPr = import nixpkgs-pr {
      #  inherit system;
      #  config = nixpkgsConfig;
      #};

      ### Replace packages here
      ### Force use gh from unstable (on system level)
      #gh = inputs.nixpkgs-unstable.legacyPackages.${super.stdenv.hostPlatform.system}.gh;
    })
  ];
}
