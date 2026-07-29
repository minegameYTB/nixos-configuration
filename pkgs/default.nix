{
  callPackage,
  flakePath,
  rev,
  branch,
  buildDate,
  repoUrl ? null,
  ...
}:

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
}
