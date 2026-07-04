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

# shellcheck disable=SC2034 # used by sourced install scripts
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

# shellcheck disable=SC2034 # used by sourced install scripts for formatted output
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
# Flag parsing & usage
# ---------------------------------------------------------------------------

# Central help text — add new flags here AND in the case below.
showUsage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

Options:
  --dont-check  Skip the git repository version check
  --help, -h    Show this help message and exit
EOF
}

# Parse all known flags from "$@" and set globals accordingly.
# Add new flags here (case branch) AND in showUsage() above.
# shellcheck disable=SC2034 # SKIP_VERSION_CHECK is set here, read by install.sh
parseFlags() {
  while (( $# )); do
    case "$1" in
      --dont-check) SKIP_VERSION_CHECK=1 ;;
      --help|-h)    showUsage; exit 0 ;;
      *)
        echo "Unknown flag: $1"
        showUsage
        exit 1
        ;;
    esac
    shift
  done
}

# ---------------------------------------------------------------------------
# Version check
# ---------------------------------------------------------------------------

# Check whether the local repo has uncommitted changes or is behind its
# upstream branch.  If behind, propose to auto-update and re-exec.
checkRepoVersion() {
  local repoRoot scriptArgs=("$@")
  repoRoot="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0

  local dirty=0 behind_count=0

  # ── uncommitted changes ───────────────────────────────────────────────────
  if ! git -C "$repoRoot" diff --quiet 2>/dev/null; then
    dirty=1
    warn "You have uncommitted changes in ${repoRoot}"
  fi

  # ── behind upstream ───────────────────────────────────────────────────────
  if git -C "$repoRoot" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' &>/dev/null; then
    git -C "$repoRoot" fetch --quiet 2>/dev/null || true
    behind_count=$(git -C "$repoRoot" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    if (( behind_count > 0 )); then
      warn "Local branch is ${behind_count} commit(s) behind upstream"
    fi
  fi

  # ── prompt ────────────────────────────────────────────────────────────────
  if (( dirty || behind_count > 0 )); then
    echo ""

    if (( behind_count > 0 )) && (( ! dirty )); then
      read -r -p "Pull latest changes and re-run? [Y/n]: " _pull
      _pull="${_pull:-Y}"
      if [[ "$_pull" =~ ^[yY]$ ]]; then
        info "Pulling latest changes..."
        if git -C "$repoRoot" pull --ff-only; then
          info "Re-executing script"
          exec "$0" "${scriptArgs[@]}"
        else
          warn "Pull failed — falling back to manual choice"
        fi
      fi
    fi

    read -r -p "Continue anyway? [y/N]: " _cont
    _cont="${_cont:-N}"
    if ! [[ "$_cont" =~ ^[yY]$ ]]; then
      info "Aborted by user"
      exit 0
    fi
  else
    info "Repository is up to date"
  fi
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
