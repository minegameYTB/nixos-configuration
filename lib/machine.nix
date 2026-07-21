{
  lib,
  overlay,
  home-manager,
  defaultArch ? "x86_64-linux",
  pkgsFor,
  pkgsPatched,
  specialArgs,
  homeManagerConfig,
  ...
}:

let
  mkMachine =
    {
      hostname,
      profile,
      fs,
      extraModules ? [ ],
      arch ? defaultArch,
      usePatched ? false,
    }:
    let
      machinePkgs = if usePatched then pkgsPatched arch else pkgsFor arch;
    in
    lib.nixosSystem {
      system = arch;
      pkgs = machinePkgs;
      specialArgs = specialArgs arch;
      modules = [
        ../configurations/configuration.nix

        profile
        fs

        (overlay arch)

        { networking.hostName = hostname; }

        home-manager.nixosModules.home-manager
        (homeManagerConfig arch)
      ]
      ++ extraModules;
    };
in
{
  inherit mkMachine;
}
