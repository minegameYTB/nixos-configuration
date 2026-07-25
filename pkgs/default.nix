{
  callPackage,
  flakePath,
  rev,
  branch,
  repoUrl ? null,
  ...
}:

{
  nixos-config = callPackage ./nixos-config/default.nix {
    inherit
      flakePath
      rev
      branch
      repoUrl
      ;
  };
}
