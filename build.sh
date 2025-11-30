#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p gnumake nix.out unzip gitMinimal jq cacert
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/1dcdcf9efc6aed8bf28347c0bfa583ba511954ae.tar.gz

### A wrapper to run make, without need to install make, nix will add make to the runtime PATH
make $1
