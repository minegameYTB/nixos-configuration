#!/usr/bin/env bash
set -euo pipefail

# Restrict PATH to known safe locations for NixOS live environments.
PATH="/bin:/usr/bin:/run/current-system/sw/bin"

# installLib points to the directory that contains lib.sh and the install
# scripts.  Using $(pwd) keeps it relocatable without hard-coded paths.
installLib="$(pwd)/install-lib"
name="$(basename -s .sh "$0")"

# Source common variables and functions (colours, logging, checkpoint system).
# shellcheck source=install-lib/lib.sh
source "$installLib/lib.sh"

# Source install method implementations.
# shellcheck source=install-lib/nixos-install.sh
source "$installLib/nixos-install.sh"
# shellcheck source=install-lib/hm-standalone-install.sh
source "$installLib/hm-standalone-install.sh"

# Parse flags (--dont-check, --help, ...).  Must come after source since
# parseFlags / showUsage are defined in lib.sh.
SKIP_VERSION_CHECK=0
parseFlags "$@"

echo "$name v2.0"
sleep 2

# ---------------------------------------------------------------------------
# Version check — warn if repo is dirty or behind upstream
# ---------------------------------------------------------------------------

if (( SKIP_VERSION_CHECK )); then
  info "Version check skipped (--dont-check)"
else
  checkRepoVersion "$@"
fi

# ---------------------------------------------------------------------------
# Detect whether we are running on NixOS or a generic Linux system.
#
# NixOS detection: both /etc/NIXOS (marker file) and /run/current-system
# (the active system profile) must be present.  Checking /run/current-system
# (rather than /bin or /sbin) avoids false positives on systems that happen
# to have an /etc/NIXOS file but are not running NixOS.
# ---------------------------------------------------------------------------

if [[ -e "/etc/NIXOS" && -d "/run/current-system" ]]; then
  info "NixOS detected (via /etc/NIXOS + /run/current-system) — running NixOS install"
  echo ""
  mode="nixosInstall"
else
  if [[ "$(uname -s)" != "Linux" ]]; then
    warn "This script is designed for Linux systems only (Error 2)"
    exit 2
  fi
  info "Non-NixOS Linux detected — running Home Manager standalone install"
  echo ""
  mode="hmInstall"
fi

case "$mode" in
  nixosInstall)
    nixosInstallFn
    ;;
  hmInstall)
    hmInstallFn
    ;;
esac
