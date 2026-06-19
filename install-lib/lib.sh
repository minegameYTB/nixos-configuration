### lib.sh — Common variables and reusable functions
### Sourced by install.sh before any install script
# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Defaults and checkpoint helpers
# ---------------------------------------------------------------------------

# shellcheck source=install-lib/defaults.sh
source "$(dirname "${BASH_SOURCE[0]}")/defaults.sh"

# shellcheck source=install-lib/checkpoint.sh
source "$(dirname "${BASH_SOURCE[0]}")/checkpoint.sh"

# ---------------------------------------------------------------------------
# Nix settings
# ---------------------------------------------------------------------------

nixFlags=(--extra-experimental-features "nix-command flakes")

# Read the pinned nixpkgs-main revision from flake.lock, fall back to a known
# good commit if the file is missing or the key is absent.
nixpkgsRev=$(jq -r '.nodes["nixpkgs-main"].locked.rev // empty' flake.lock 2>/dev/null) \
  || nixpkgsRev=""

if [[ -z "$nixpkgsRev" || "$nixpkgsRev" == "null" ]]; then
  nixpkgsRev="$INSTALL_NIXPKGS_FALLBACK_REV"
fi

# ---------------------------------------------------------------------------
# ANSI colour variables
# Disabled when: NO_COLOR is set, TERM=dumb, or stdout is not a terminal.
# ---------------------------------------------------------------------------

if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-dumb}" == "dumb" ]] || ! [[ -t 1 ]]; then
  BOLD="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" RESET=""
else
  BOLD='\033[1m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[1;34m'
  MAGENTA='\033[1;35m'
  CYAN='\033[1;36m'
  RESET='\033[0m'
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

warn() {
  printf '%b\n' "${MAGENTA}warning:${RESET} $*" >&2
}

info() {
  printf '%b\n' "${CYAN}info:${RESET} $*"
}

# Print the command before running it so the user can see what is happening.
run_command() {
  printf '%b\n' "\n${BLUE}▶ Run command:${RESET}"
  printf '%b\n\n' "  ${YELLOW}$*${RESET}"
  "$@"
}

# ---------------------------------------------------------------------------
# Username helper
# ---------------------------------------------------------------------------

# Read the default username from the install defaults and prompt the user to
# confirm or override it.
# Usage  : getDefaultUser <error_code>
# Exports: userName
getDefaultUser() {
  local errorCode="${1:-5}"

  read -r -p "What is your username? [${INSTALL_DEFAULT_USER}] " userName
  userName="${userName:-$INSTALL_DEFAULT_USER}"

  if [[ -z "$userName" ]]; then
    warn "No username provided and default user is unset (Error $errorCode)"
    exit "$errorCode"
  fi
}
