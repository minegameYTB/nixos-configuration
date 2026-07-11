{
  callPackage,
  src,
  rev,
  branch,
  repoUrl ? null,
  ...
}:

{
  nixos-config = callPackage ./nixos-config/default.nix {
    inherit
      src
      rev
      branch
      repoUrl
      ;
  };
}
