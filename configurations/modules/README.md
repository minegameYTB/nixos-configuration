# This directory is for modules

to use declared modules, when you created a new profile (configuration) for a new machine

add this line to (nixos-configuration root)/profiles/<machine name>-profiles.nix : "../configurations/modules" or "../../configurations/modules" if the targeted machine profiles is in (nixos-configuration root)/profiles/base-profiles

(see flake.nix for more details for implementing new profiles)

# How it's work ?

by doing this, nix will import all expression declared in modules/default.nix, the modules will be imported following import of default.nix (see /configurations/modules/default.nix implementation)
