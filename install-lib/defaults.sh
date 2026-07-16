### defaults.sh — Shared install defaults
### Sourced by lib.sh before install logic
# shellcheck shell=bash

# Single place for values that are otherwise duplicated between scripts.
INSTALL_DEFAULT_USER="${INSTALL_DEFAULT_USER:-minegame}"
INSTALL_STATE_FILE="${INSTALL_STATE_FILE:-/tmp/nixos-install-state}"
INSTALL_NIXPKGS_FALLBACK_REV="${INSTALL_NIXPKGS_FALLBACK_REV:-23d72dabcb3b12469f57b37170fcbc1789bd7457}"
INSTALL_SCRIPT_VERSION="${INSTALL_SCRIPT_VERSION:-2.1}"
INSTALL_REPO_URL="${INSTALL_REPO_URL:-}"
