{
  callPackage,
  pkgs,
  lib,
  flakePath,
  rev,
  branch,
  buildDate,
  repoUrl ? null,
  ...
}:

let
  # Tight per-service envs also exposed as standalone flake packages
  # (so `nix build '.#nixos-auto-update-env-main' && ls result/bin` works
  # without evaluating a full NixOS config). The system wiring in
  # services.nix uses the real `config.systemd.package` / `config.nix.package`
  # / `config.system.build.nixos-rebuild`; here we use the pkgs equivalents
  # plus a dummy nixos-rebuild for the standalone build.
  autoUpdateEnvs = pkgs.callPackage ../configurations/modules/misc/auto-update/env.nix {
    inherit lib;
    config = {
      systemd.package = pkgs.systemd;
      nix.package = pkgs.nix;
      system.build.nixos-rebuild = pkgs.writeScriptBin "nixos-rebuild" ''exec echo "dummy nixos-rebuild for env check" "$@"'';
    };
  };
in
{
  nixos-config = callPackage ./nixos-config/default.nix {
    inherit
      flakePath
      rev
      branch
      buildDate
      repoUrl
      ;
  };

  nspawnctl = callPackage ./nspawnctl/default.nix { };

  nixos-auto-update-env-core = autoUpdateEnvs.core;
  nixos-auto-update-env-health = autoUpdateEnvs.health;
  nixos-auto-update-env-main = autoUpdateEnvs.main;
  nixos-auto-update-envs = pkgs.symlinkJoin {
    name = "nixos-auto-update-envs";
    # Explicit list: callPackage wraps the result with makeOverridable, so
    # builtins.attrValues would also yield `override`/`overrideDerivation`
    # (callable sets, not derivations) and symlinkJoin fails to coerce them.
    paths = [
      autoUpdateEnvs.core
      autoUpdateEnvs.health
      autoUpdateEnvs.main
    ];
  };
}
