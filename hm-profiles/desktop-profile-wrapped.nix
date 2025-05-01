{ username, extraModules ? [], ... }@args:

let
  baseProfile = import ./desktop-profile.nix { inherit username; };
in
baseProfile // {
  imports = (baseProfile.imports or []) ++ extraModules;
}

