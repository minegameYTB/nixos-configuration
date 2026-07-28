{
  lib,
  system,
  inputs,
  nixpkgsConfig,
  rev,
  branch,
  repoUrl,
  self,
  ...
}:

### autocomplete with inputs in early step here to avoid repeat "inputs.[...].args"
with inputs;
{
  nixpkgs.overlays =
    ### Extend pkgs with nur namespace
    [ nur.overlays.default ]

    ### CachyOS kernel & glfOS apps (x86_64 only)
    ++ lib.optionals (system == "x86_64-linux") [
      nix-cachyos-kernel.overlays.pinned
      glfOS-modules.overlays.default
    ]

    ### Custom extend of pkgs or replacing pkgs by other
    ++ (
      let
        ### Capture flake self before inner overlay shadows it
        flake = self;
      in
      [
        (self: super: rec {
          #nur = import inputs.nur {
          #  nurpkgs = pkgsUnstable;
          #  pkgs = pkgsUnstable;
          #};

          ### Extend pkgs namespace here
          # inject pkgs-<release> in pkgs namespace instead of pkgsExtra variable
          pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};
          pkgs2511 = nixpkgs-25-11.legacyPackages.${system};
          #pkgsLts = import ctrl-os {
          #  inherit system;
          #  config = nixpkgsConfig;
          #};
          #pkgsMaster = import nixpkgs-master {
          #  inherit system;
          #  config = nixpkgsConfig;
          #};
          pkgsPr = nixpkgs-pr.legacyPackages.${system};

          ### Config packages namespace — delegates to pkgs/default.nix
          pkgsConfig = super.callPackage ./pkgs/default.nix {
            flakePath = flake.outPath;
            inherit rev branch repoUrl;
          };

          ### Replace packages here
          ### Force use gh from unstable (on system level)
          #gh = inputs.nixpkgs-unstable.legacyPackages.${super.stdenv.hostPlatform.system}.gh;
        })
      ]
    );
}
