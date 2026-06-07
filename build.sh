#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p gnumake nix.out unzip gitMinimal jq cacert deadnix
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/8c50a710ddca43d7a530fb805ad55bde8d0141c5.tar.gz

### A wrapper to run make, without need to install make, nix will add make to the runtime PATH
make $1
