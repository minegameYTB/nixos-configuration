#!/usr/bin/env bash
set -euo pipefail

### A wrapper to run make via nix develop (uses devShell from flake.nix)
nix develop --command make "$@"
