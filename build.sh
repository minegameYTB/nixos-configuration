#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p gnumake nix nixfmt-rfc-style statix deadnix findutils unzip git jq cacert
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/88331c17ba434359491e8d5889cce872464052c2.tar.gz

### A wrapper to run make, without need to install make, nix will add make to the runtime PATH
make $1
