#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p gnumake nix.out unzip gitMinimal jq cacert
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/50a96edd8d0db6cc8db57dab6bb6d6ee1f3dc49a.tar.gz

### A wrapper to run make, without need to install make, nix will add make to the runtime PATH
make $1
