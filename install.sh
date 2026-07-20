#!/usr/bin/env bash
set -euo pipefail

# Restrict PATH to known safe locations for NixOS live environments.
# /run/wrappers/bin is where NixOS places setuid wrappers (sudo).
PATH="/run/wrappers/bin:/bin:/usr/bin:/run/current-system/sw/bin"

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

# Parse flags (--dont-check, --help, --list-steps, --step, ...).
# Must come after source since parseFlags / showUsage are defined in lib.sh.
SKIP_VERSION_CHECK=0
LIST_STEPS=""
ONLY_STEP=""
parseFlags "$@"

# Handle --list-steps (exits immediately, no version check needed)
if [[ -n "${LIST_STEPS:-}" ]]; then
  listSteps
  exit 0
fi

if [[ -n "${ONLY_STEP:-}" ]]; then
  info "Running only step: ${ONLY_STEP}"
fi

echo "$name v$INSTALL_SCRIPT_VERSION"
sleep 2

# ---------------------------------------------------------------------------
# Phase 1 — Version check (user only, git should not run as root)
# ---------------------------------------------------------------------------

if (( SKIP_VERSION_CHECK )); then
  info "Version check skipped (--dont-check)"
else
  checkRepoVersion "$@"
fi

# ---------------------------------------------------------------------------
# Phase 2 — Detect install mode (no root needed for detection)
#
# NixOS detection: both /etc/NIXOS (marker file) and /run/current-system
# (the active system profile) must be present.  Checking /run/current-system
# (rather than /bin or /sbin) avoids false positives on systems that happen
# to have an /etc/NIXOS file but are not running NixOS.
# ---------------------------------------------------------------------------

if [[ -e "/etc/NIXOS" && -d "/run/current-system" ]]; then
  info "NixOS detected (via /etc/NIXOS + /run/current-system) — running NixOS install"
  mode="nixosInstall"
else
  if [[ "$(uname -s)" != "Linux" ]]; then
    warn "This script is designed for Linux systems only (Error 2)"
    exit 2
  fi
  info "Non-NixOS Linux detected — running Home Manager standalone install"
  mode="hmInstall"
fi

# ---------------------------------------------------------------------------
# Phase 3 — Auto-elevation (NixOS install only, HM runs as normal user)
# ---------------------------------------------------------------------------

if [[ $EUID -ne 0 ]] && [[ "$mode" == "nixosInstall" ]]; then
  info "Root privileges required — re-running with sudo..."
  exec sudo "$0" --dont-check "$@"
fi

# ---------------------------------------------------------------------------
# Phase 4 — Dispatch
# ---------------------------------------------------------------------------

case "$mode" in
  nixosInstall) nixosInstallFn ;;
  hmInstall)    hmInstallFn ;;
esac

exit $?
