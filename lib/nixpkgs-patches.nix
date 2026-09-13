### Out-of-tree nixpkgs patches — canonical patch list for pkgsPatched.
### Consumed by flake.nix (nixpkgs-patched); machines opt in per-machine with
### `usePatched = true` in machine.nix (needs a rebuild switch — keep it off otherwise).
###
### PR patches go through pkgs.fetchpatch (not fetchurl): it strips the volatile
### diff headers, so the hash only changes when the patch content really changes.
### New hash needed? Put a dummy hash and copy the expected one from the build error.
###
### Local patches resolve relative to this file (repo root = ../), applied with -p1.
{
  pkgs,
  lib,
}:
let
  ### Patch sources: GitHub PR patches (url + hash) or local patch files
  patchList = [
    {
      ### libcap_ng static fix (doCheck=false when isStatic) — remove after merge
      ### https://github.com/NixOS/nixpkgs/pull/562812 (fixes #562705, upstream stevegrubb/libcap-ng#85)
      url = "https://github.com/NixOS/nixpkgs/pull/562812.patch";
      hash = "sha256-BgXRpxLl561YrlsUNJ5QmNELDHZThkLZHWJ+6At7wq0=";
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
