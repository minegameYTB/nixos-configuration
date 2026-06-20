### checkpoint.sh — Resume / checkpoint helpers for the installers
### Sourced by lib.sh after defaults.sh
# shellcheck shell=bash

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
# Override: INSTALL_STATE_FILE=/path/to/file ./install.sh
#
# /tmp is intentionally used for normal installs because it disappears on
# reboot.  If you want to survive a machine crash and resume after a reboot,
# set INSTALL_STATE_FILE to a path on already-mounted persistent storage, e.g.
# INSTALL_STATE_FILE=/mnt/nixos-install-state
# ---------------------------------------------------------------------------

STATE_FILE="${INSTALL_STATE_FILE:-/tmp/nixos-install-state}"

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
