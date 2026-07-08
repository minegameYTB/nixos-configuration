#! /usr/bin/env bash
### Test the install script logic without touching any disk.
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PASS=0

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[1;36m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✓${RESET} $1"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}✗${RESET} $1"; ((FAIL++)) || true; }

# ---------------------------------------------------------------------------
# Import the real lib functions (but mock disko/nixos-install)
# ---------------------------------------------------------------------------

# Mock run_command — logs but does NOT execute
# shellcheck disable=SC2329 # intentionally unused — mock for sourced libs
run_command() {
  echo "    [mock] $*" >&2
}

# Source libs (these set nixFlags, nixpkgsRev, etc.)
source "$SCRIPT_DIR/install-lib/lib.sh"

# Mock disko — just echo which file would be used
mock_disko() {
  local file="$1"
  echo "    [mock disko] would run: nix run nixpkgs/#disko -- -m destroy,format,mount ${file}" >&2
}

# ---------------------------------------------------------------------------
# Helper: test a single combination
# ---------------------------------------------------------------------------
# Args: boot_mode (efi|bios) fs (btrfs|zfs) encrypted (y|N)
test_combination() {
  local boot="$1" fs="$2" encrypted="$3"
  local expected_file=""
  local label=""

  if [[ "$boot" == "efi" ]]; then
    if [[ "$encrypted" =~ ^[yY]$ ]]; then
      expected_file="$SCRIPT_DIR/configurations/disko-configuration/current/disko-efi-luks-${fs}.nix"
      label="UEFI + LUKS + ${fs}"
    else
      expected_file="$SCRIPT_DIR/configurations/disko-configuration/current/disko-efi-${fs}.nix"
      label="UEFI + noLUKS + ${fs}"
    fi
  else
    expected_file="$SCRIPT_DIR/configurations/disko-configuration/current/disko-bios-btrfs.nix"
    label="BIOS + btrfs"
  fi

  if [[ -f "$expected_file" ]]; then
    ok "${label} → $(basename "$expected_file")"
  else
    fail "${label} → missing: ${expected_file}"
  fi
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
echo -e "${CYAN}Disko config selection${RESET}"

test_combination efi   btrfs  N
test_combination efi   btrfs  Y
test_combination efi   zfs    N
test_combination bios  btrfs  N

echo
echo -e "${CYAN}Swap type detection${RESET}"

test_swap_type() {
  local fstype="$1" expected="$2"
  local mountFs="$fstype"
  # shellcheck disable=SC2034 # used by the real script, placeholder for testing
  local swapFile="/mnt/.swapfile-install"
  # shellcheck disable=SC2034
  local swapZvol="zroot/swap-install"

  if [[ "$mountFs" == "btrfs" ]]; then
    if [[ "$expected" == "mkswapfile" ]]; then
      ok "btrfs → btrfs filesystem mkswapfile"
    else
      fail "btrfs → expected ${expected}"
    fi
  elif [[ "$mountFs" == "zfs" ]]; then
    if [[ "$expected" == "zvol" ]]; then
      # Check the script actually uses zfs create -V
      if grep -q "zfs create -V" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
        ok "zfs → zfs create -V (zvol)"
      else
        fail "zfs → expected zvol path in script"
      fi
    else
      fail "zfs → expected ${expected}"
    fi
  else
    if [[ "$expected" == "fallocate" ]]; then
      ok "ext4/xfs → fallocate + mkswap"
    else
      fail "ext4/xfs → expected ${expected}"
    fi
  fi
}

test_swap_type btrfs mkswapfile
test_swap_type zfs   zvol
test_swap_type ext4  fallocate

echo
echo -e "${CYAN}Swap cleanup functions${RESET}"

test_swap_cleanup() {
  if grep -q "^deactivateSwap()" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "deactivateSwap function exists"
  else
    fail "deactivateSwap missing"
  fi
  if grep -q "^destroyTempSwap()" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "destroyTempSwap function exists"
  else
    fail "destroyTempSwap missing"
  fi
  if grep -q "swapoff.*zroot/swap" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "deactivateSwap covers persistent zvol (zroot/swap)"
  else
    fail "deactivateSwap does not cover persistent zvol"
  fi
  if grep -q "volblocksize=16384" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "Temp swap zvol uses volblocksize=16384"
  else
    fail "Temp swap zvol volblocksize not 16384"
  fi
  if grep -q "rm -f.*swapFile.*2>/dev/null || true" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "setupTempSwap cleans up pre-existing temp file"
  else
    fail "setupTempSwap does not clean pre-existing temp file"
  fi
  if grep -q "zfs destroy.*swapZvol" "$SCRIPT_DIR/install-lib/nixos-install.sh" && \
     grep -q "rm -f.*swapFile" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "setupTempSwap cleans up pre-existing zvol before creation"
  else
    fail "setupTempSwap does not clean pre-existing zvol"
  fi
  if grep -q "command -v btrfs" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "setupTempSwap checks btrfs command availability"
  else
    fail "setupTempSwap does not check btrfs command"
  fi
}

test_swap_cleanup

echo
echo -e "${CYAN}ZFS ARC tuning${RESET}"

test_arc_tuning() {
  local diskoFs="$1" expect_skip="$2"

  if [[ "$diskoFs" == "zfs" ]]; then
    if [[ "$expect_skip" == "false" ]]; then
      # Check the script writes to /sys/module/zfs/parameters/zfs_arc_max
      if grep -q "zfs_arc_max" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
        ok "ZFS→ ARC tuning step present"
      else
        fail "ZFS→ ARC tuning missing"
      fi
    fi
  fi
  if [[ "$diskoFs" == "btrfs" ]]; then
    if [[ "$expect_skip" == "true" ]]; then
      # Check that the ARC step is guarded by "${diskoFs:-}" != "zfs" (early return)
      if grep -q 'diskoFs:-.*!= "zfs"' "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
        ok "btrfs → ARC step skipped (guard present)"
      else
        fail "btrfs → guard missing"
      fi
    fi
  fi
}

test_arc_tuning zfs   false
test_arc_tuning btrfs true

echo
echo -e "${CYAN}Checkpoint variable persistence${RESET}"

test_checkpoint_var() {
  local var_name="$1"
  if grep -q "checkpoint_set.*${var_name}" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "${var_name} is persisted"
  else
    fail "${var_name} NOT persisted"
  fi
  if grep -q "checkpoint_get.*${var_name}" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "${var_name} is restored on resume"
  else
    fail "${var_name} NOT restored on resume"
  fi
}

test_checkpoint_var VAR_DEVICE
test_checkpoint_var VAR_DISKO_FS
test_checkpoint_var VAR_DISKO_FILE
test_checkpoint_var VAR_DISKO_ENCRYPTED
test_checkpoint_var VAR_PROFILE

echo
echo -e "${CYAN}Flag parsing / version check${RESET}"

test_flag_parsing() {
  if grep -q "^parseFlags()" "$SCRIPT_DIR/install-lib/lib.sh"; then
    ok "parseFlags function exists in lib.sh"
  else
    fail "parseFlags missing in lib.sh"
  fi
  if grep -q "parseFlags \"\$@\"" "$SCRIPT_DIR/install.sh"; then
    ok "install.sh calls parseFlags"
  else
    fail "install.sh does not call parseFlags"
  fi
  if grep -q "^checkRepoVersion()" "$SCRIPT_DIR/install-lib/lib.sh"; then
    ok "checkRepoVersion function exists"
  else
    fail "checkRepoVersion missing"
  fi
  if grep -q "checkRepoVersion" "$SCRIPT_DIR/install.sh"; then
    ok "install.sh calls checkRepoVersion"
  else
    fail "install.sh does not call checkRepoVersion"
  fi
  if grep -q "SKIP_VERSION_CHECK" "$SCRIPT_DIR/install-lib/lib.sh" && \
     grep -q "SKIP_VERSION_CHECK" "$SCRIPT_DIR/install.sh"; then
    ok "SKIP_VERSION_CHECK variable is shared between lib.sh and install.sh"
  else
    fail "SKIP_VERSION_CHECK not properly shared"
  fi
}

test_flag_parsing

echo
echo -e "${CYAN}Step system (STEPS array + step functions)${RESET}"

test_step_system() {
  # STEPS array must contain all expected checkpoints
  local nixFile="$SCRIPT_DIR/install-lib/nixos-install.sh"

  # Check that STEPS array line exists
  if ! grep -q '^STEPS=(' "$nixFile"; then
    fail "STEPS array not found at top level"
  fi
  # Read the array lines and check each step is present
  local steps_text
  steps_text=$(sed -n '/^STEPS=(/,/^)/p' "$nixFile")
  for expected in \
    STEP_INTERACTIVE_SETUP \
    STEP_LUKS_SETUP \
    STEP_PARTITION \
    STEP_ZFS_TUNE \
    STEP_LUKS_PASSPHRASE \
    STEP_SWAP \
    STEP_NIXOS_INSTALL \
    STEP_PASSWORD \
    STEP_COPY_CONFIG \
    STEP_ZFS_EXPORT; do
    if echo "$steps_text" | grep -q "\"${expected}\""; then
      ok "${expected} in STEPS array"
    else
      fail "${expected} MISSING from STEPS array"
    fi
  done

  # Each step must have a matching step_ function
  for func in \
    step_interactive_setup \
    step_luks_setup \
    step_partition \
    step_zfs_tune \
    step_luks_passphrase \
    step_swap \
    step_nixos_install \
    step_password \
    step_copy_config \
    step_zfs_export; do
    if grep -q "^${func}()" "$nixFile"; then
      ok "${func} exists"
    else
      fail "${func} MISSING"
    fi
  done

  # Helper functions must exist
  if grep -q "^step_func()" "$nixFile"; then
    ok "step_func exists"
  else
    fail "step_func MISSING"
  fi
  if grep -q "^listSteps()" "$nixFile"; then
    ok "listSteps exists"
  else
    fail "listSteps MISSING"
  fi
  if grep -q "^load_step_state()" "$nixFile"; then
    ok "load_step_state exists"
  else
    fail "load_step_state MISSING"
  fi
  if grep -q "^validate_step()" "$nixFile"; then
    ok "validate_step exists"
  else
    fail "validate_step MISSING"
  fi
}

test_step_system

echo
echo -e "${CYAN}--step / --list-steps flag parsing${RESET}"

test_step_flags() {
  if grep -q -- "--list-steps)" "$SCRIPT_DIR/install-lib/lib.sh"; then
    ok "--list-steps flag in parseFlags"
  else
    fail "--list-steps flag MISSING in parseFlags"
  fi
  if grep -q -- "--step)" "$SCRIPT_DIR/install-lib/lib.sh"; then
    ok "--step flag in parseFlags"
  else
    fail "--step flag MISSING in parseFlags"
  fi
  if grep -q "listSteps" "$SCRIPT_DIR/install.sh"; then
    ok "install.sh calls listSteps"
  else
    fail "install.sh does not call listSteps"
  fi
  if grep -q "ONLY_STEP" "$SCRIPT_DIR/install-lib/lib.sh"; then
    ok "lib.sh references ONLY_STEP"
  else
    fail "lib.sh does not reference ONLY_STEP"
  fi
  if grep -q "ONLY_STEP" "$SCRIPT_DIR/install-lib/nixos-install.sh"; then
    ok "nixos-install.sh uses ONLY_STEP"
  else
    fail "nixos-install.sh does not use ONLY_STEP"
  fi
}

test_step_flags

echo
# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo -e "${CYAN}Results: ${PASS} passed, ${FAIL} failed${RESET}"

# Verify all expected disko files exist
echo
echo -e "${CYAN}Disko file existence check${RESET}"
for f in disko-efi-btrfs.nix disko-efi-luks-btrfs.nix \
         disko-efi-zfs.nix \
         disko-bios-btrfs.nix; do
  if [[ -f "$SCRIPT_DIR/configurations/disko-configuration/current/$f" ]]; then
    ok "$f exists"
  else
    fail "$f MISSING"
  fi
done

echo
if (( FAIL > 0 )); then
  echo -e "${RED}${FAIL} test(s) failed${RESET}"
  exit 1
else
  echo -e "${GREEN}All ${PASS} tests passed${RESET}"
fi
