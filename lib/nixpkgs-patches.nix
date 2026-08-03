### Out-of-tree nixpkgs patches — single source of truth for pkgsPatched
###
### Imported by flake.nix (nixpkgs-patched) and applied to the nixpkgs-main
### input, then used by machines with `usePatched = true` (lib/machine.nix).
###
### The name suffix of the patched nixpkgs is derived from the patch sources
### themselves (pure eval, nothing manual): the PR number is extracted from
### the GitHub URL, the base nixpkgs rev comes from flake.lock (flake.nix).
### The PR *commit* hash is not in the URL, and the patch file (where the
### `From <hash>` header lives) is only readable at build time, not eval —
### so a flake input would be needed to trace it. Not worth it.
###
### PR patches: use pkgs.fetchpatch instead of builtins.fetchurl. fetchpatch
### normalizes the diff (filterdiff --clean strips the volatile `index`/
### `From`/timestamp headers), so the hash only changes when the patch
### content actually changes — no more stale-hash breakage on every PR
### force-push/update.
###
### Building / testing
###
###   # Plain nixpkgs source (unpatched)
###   nix build --impure --expr '
###     let f = builtins.getFlake "path:/home/minegame/nixos-configuration";
###     in f.inputs.nixpkgs-main'
###
###   # Patched source — store path embeds the base rev + patch ids:
###   #   nixpkgs-patched-<base rev>-pr<number>-<local basenames>
###   nix build --impure --expr '
###     let f = builtins.getFlake "path:/home/minegame/nixos-configuration";
###         pkgs = f.inputs.nixpkgs-main.legacyPackages.x86_64-linux;
###         patches = import ./lib/nixpkgs-patches.nix { inherit pkgs; lib = pkgs.lib; };
###     in pkgs.applyPatches {
###       name = "nixpkgs-patched-${f.inputs.nixpkgs-main.shortRev}-${patches.name}";
###       src = f.inputs.nixpkgs-main;
###       inherit (patches) patches;
###     }'
###
### usePatched option (lib/machine.nix)
###
###   mkMachine in machine.nix accepts `usePatched ? false`: when true the
###   machine's pkgs come from pkgsPatched (this file) instead of pkgsFor.
###   The pkgs is passed explicitly to nixosSystem, so a rebuild switch is
###   needed; do not leave it enabled on machines that must stay unpatched.
###
###     # machine.nix
###     hp-probook = mkMachine {
###       ...
###       usePatched = true;
###     };
###
###   Verify the eval really pulls the patched tree:
###
###     nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath
###
###   (drvPath differs from the unpatched build and the nixpkgs-patched-*
###   drv/output appears in the store).
###
### Getting the hash: set a dummy value and build (or temporarily enable
### usePatched on a machine), then copy the hash from the error message:
###
###   nix build --impure --expr '
###     let f = builtins.getFlake "path:/home/minegame/nixos-configuration";
###         pkgs = f.inputs.nixpkgs-main.legacyPackages.x86_64-linux;
###     in pkgs.applyPatches {
###       name = "nixpkgs-patched";
###       src = f.inputs.nixpkgs-main;
###       patches = (import ./lib/nixpkgs-patches.nix { inherit pkgs; lib = pkgs.lib; }).patches;
###     }'
###
### Local patches: relative paths are resolved from this file's directory
### (repo root = ../), applied with -p1 — keep fetchpatch's default
### stripLen = 0 so the a/ b/ path prefixes survive.
{
  pkgs,
  lib,
}:
let
  ### Patch sources: GitHub PR patches (url + hash) or local patch files
  patchList = [
    {
      ### claude-desktop PR — append ".patch" to the PR URL
      url = "https://github.com/NixOS/nixpkgs/pull/537215.patch";
      hash = "sha256-C5ly3Lpl5Kqohwv0OLR3qwBQOvPCni4/Rpg5vywNv60=";
    }

    ### Local patches (uncomment as needed)
    #../configurations/patch/nixpkgs/0000-qemu-fix-version.patch
    #../configurations/patch/nixpkgs/0000-libvirt-update.patch
  ];

  ### Short identifier per source used in the patched nixpkgs name:
  ### "pr<number>" for GitHub PR patches, basename (without .patch) for local
  ### patch files
  patchId =
    p:
    if builtins.isPath p || builtins.isString p then
      lib.removeSuffix ".patch" (baseNameOf (toString p))
    else
      let
        ### e.g. https://github.com/NixOS/nixpkgs/pull/537215.patch
        pr = builtins.match ".*/pull/([0-9]+)\\.patch" p.url;
      in
      if pr == null then baseNameOf p.url else "pr${lib.head pr}";

  ### fetchpatch for GitHub PRs, local file as-is otherwise
  toPatch =
    p:
    if builtins.isPath p || builtins.isString p then
      p
    else
      pkgs.fetchpatch {
        inherit (p) url hash;
        name = "nixpkgs-${patchId p}.patch";
      };
in
{
  ### Name suffix describing the applied patches (store paths of pkgsPatched
  ### builds, nix tools) — derived from the patch sources (pure, eval-time)
  name = lib.concatMapStringsSep "-" patchId patchList;

  patches = map toPatch patchList;
}
