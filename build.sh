#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p gnumake nix.out unzip gitMinimal jq cacert deadnix
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/c06b4ae3d6599a672a6210b7021d699c351eebda.tar.gz

### A wrapper to run make, without need to install make, nix will add make to the runtime PATH
make $1
