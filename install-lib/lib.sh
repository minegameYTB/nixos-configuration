### lib.sh — Common variables and reusable functions
### Sourced by install.sh before any install script

# ---------------------------------------------------------------------------
# Nix settings
# ---------------------------------------------------------------------------

nixFlags=(--extra-experimental-features "nix-command flakes")

# Read the pinned nixpkgs-main revision from flake.lock, fall back to a known
# good commit if the file is missing or the key is absent.
nixpkgsRev=$(jq -r '.nodes["nixpkgs-main"].locked.rev // empty' flake.lock 2>/dev/null) \
  || nixpkgsRev=""

if [[ -z "$nixpkgsRev" || "$nixpkgsRev" == "null" ]]; then
  nixpkgsRev="23d72dabcb3b12469f57b37170fcbc1789bd7457"
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
  printf "${MAGENTA}warning:${RESET} %s\n" "$*" >&2
}

info() {
  printf "${CYAN}info:${RESET} %s\n" "$*"
}

# Print the command before running it so the user can see what is happening.
run_command() {
  printf "\n${BLUE}▶ Run command:${RESET}"
  printf "  ${YELLOW}%s${RESET}\n\n" "$*"
  "$@"
}

# ---------------------------------------------------------------------------
# Username helper
# ---------------------------------------------------------------------------

# Read the default username from flake.nix (users = [ "..." ]) and prompt the
# user to confirm or override it.
# Usage  : getDefaultUser <error_code>
# Exports: userName
getDefaultUser() {
  local errorCode="${1:-5}"

  local default_user
  default_user=$(grep -oP '(?<=users = \[ ")[^"]+' flake.nix 2>/dev/null | head -1 || true)

  read -r -p "What is your username? [${default_user}] " userName
  userName="${userName:-$default_user}"

  if [[ -z "$userName" ]]; then
    warn "No username provided and could not parse flake.nix (Error $errorCode)"
    exit "$errorCode"
  fi
}

# ---------------------------------------------------------------------------
# Checkpoint / resume system
# ---------------------------------------------------------------------------
#
# How it works
# ~~~~~~~~~~~~
# Every long or destructive step in the install functions is wrapped with:
#
#   if ! checkpoint_skip "STEP_FOO"; then
#     ... do the work ...
#     checkpoint_done "STEP_FOO"
#   fi
#
# checkpoint_done writes "STEP_FOO=done" to STATE_FILE.
# checkpoint_skip returns 0 (true) when that line is already present, causing
# the surrounding `if ! ...` block to be skipped on a resume run.
#
# Variables that are collected interactively (device path, profile name, …)
# are persisted with checkpoint_set / checkpoint_get so they survive a crash
# and do not need to be re-entered on resume.
#
# State file location
# ~~~~~~~~~~~~~~~~~~~
# Default: /tmp/nixos-install-state
# Override: STATE_FILE=/path/to/file ./install.sh
#
# /tmp is intentionally used for normal installs because it disappears on
# reboot.  If you want to survive a machine crash and resume after a reboot,
# set STATE_FILE to a path on already-mounted persistent storage, e.g.
# STATE_FILE=/mnt/nixos-install-state
# ---------------------------------------------------------------------------

STATE_FILE="${STATE_FILE:-/tmp/nixos-install-state}"

# Mark a step as successfully completed.
# Usage: checkpoint_done <step_name>
checkpoint_done() {
  local step="$1"
  # Remove any existing entry for this step, then append the new one.
  grep -v "^${step}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
  echo "${step}=done" >> "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
  info "Checkpoint: '${step}' marked as done"
}

# Return 0 (skip) if the step is already done, 1 (run) otherwise.
# Designed for:  if ! checkpoint_skip "STEP_FOO"; then ... fi
# This is safe under set -e because the return value is consumed by `if`.
# Usage: checkpoint_skip <step_name>
checkpoint_skip() {
  local step="$1"
  if grep -q "^${step}=done" "$STATE_FILE" 2>/dev/null; then
    info "Skipping '${step}' (already completed)"
    return 0
  fi
  return 1
}

# Persist an arbitrary key=value pair in the state file.
# Used to save interactive inputs (device, profile, …) so they can be
# restored on resume without asking the user again.
# Usage: checkpoint_set <key> <value>
checkpoint_set() {
  local key="$1" val="$2"
  grep -v "^${key}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
  echo "${key}=${val}" >> "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Read a previously saved value from the state file.
# Prints nothing (empty string) when the key is absent.
# Usage: var=$(checkpoint_get <key>)
checkpoint_get() {
  local key="$1"
  grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2- || true
}

# Delete the state file after a fully successful install.
checkpoint_clear() {
  rm -f "$STATE_FILE"
  info "State file cleared — install completed successfully"
}

# Offer to resume a previous session or start fresh.
# Called at the top of each install function when STATE_FILE already exists.
# Sets the global RESUMING variable (1 = resume, 0 = fresh start).
# Usage: checkpoint_resume_prompt
checkpoint_resume_prompt() {
  RESUMING=0

  if [[ ! -f "$STATE_FILE" ]]; then
    return
  fi

  warn "A previous install session was found (${STATE_FILE})"
  read -r -p "Resume previous install? [Y/n]: " _resume_answer
  if [[ "${_resume_answer:-Y}" =~ ^[nN]$ ]]; then
    info "Starting fresh — clearing previous state"
    checkpoint_clear
  else
    info "Resuming — completed steps will be skipped automatically"
    RESUMING=1
  fi
}
