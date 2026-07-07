### nixos-install.sh — NixOS installation on a bare machine
### Sourced by install.sh; requires lib.sh (and thus checkpoint.sh / defaults.sh) to be sourced first.
# shellcheck shell=bash
# shellcheck disable=SC2154 # nixFlags, nixpkgsRev set by lib.sh sourced earlier

# ── Steps ──────────────────────────────────────────────────
# Single source of truth for all installation steps.
# To add a new step:
#   1. Write step_foo_bar() { ... }
#   2. Add "STEP_FOO_BAR" to this array
#   3. The dispatch loop and --step mode pick it up automatically
# ────────────────────────────────────────────────────────────
STEPS=(
  "STEP_INTERACTIVE_SETUP"
  "STEP_LUKS_SETUP"
  "STEP_PARTITION"
  "STEP_ZFS_TUNE"
  "STEP_LUKS_PASSPHRASE"
  "STEP_SWAP"
  "STEP_NIXOS_INSTALL"
  "STEP_PASSWORD"
  "STEP_COPY_CONFIG"
  "STEP_ZFS_EXPORT"
)

# Derive the step function name from a checkpoint name.
#   STEP_FOO_BAR → step_foo_bar
step_func() {
  local checkpoint="$1"
  local name="${checkpoint#STEP_}"
  echo "step_${name,,}"
}

# List all known steps with a short description.
listSteps() {
  info "Available installation steps:"
  for s in "${STEPS[@]}"; do
    echo "  ${s}"
  done
  echo ""
  info "Usage: ./install.sh --step STEP_NAME"
}

# Load persisted variables from the checkpoint state file.
# Called when RESUMING=1 or when --step is used.
load_step_state() {
  deviceDisk="$(checkpoint_get   "VAR_DEVICE")"
  sizeDisk="$(checkpoint_get     "VAR_SIZE")"
  nixosProfile="$(checkpoint_get "VAR_PROFILE")"
  diskoFile="$(checkpoint_get    "VAR_DISKO_FILE")"
  diskoFs="$(checkpoint_get      "VAR_DISKO_FS")"
  diskoEncrypted="$(checkpoint_get "VAR_DISKO_ENCRYPTED")"
  keyFile="$(checkpoint_get      "VAR_KEY_FILE")"
  addPassphrase="$(checkpoint_get "VAR_ADD_PASSPHRASE")"
  luksKeySize="$(checkpoint_get  "VAR_LUKS_KEY_SIZE")"
  userName="$(checkpoint_get     "VAR_USERNAME")"
}

# Validate that a step name is known and its function exists.
validate_step() {
  local step="$1"
  if ! printf '%s\n' "${STEPS[@]}" | grep -qx "$step"; then
    warn "Unknown step: ${step}"
    listSteps
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Disk helpers
# ---------------------------------------------------------------------------

showDiskLsblk() {
  echo "Available block devices:"
  lsblk -d -n -o NAME,SIZE,TYPE | grep -E '^(sd|vd|nvme|hd|mmcblk)' || true
}

# ---------------------------------------------------------------------------
# RAM detection
# ---------------------------------------------------------------------------

# Detect total RAM and decide whether a temporary swap file is needed.
#
# Swap is created when RAM < SWAP_THRESHOLD_GiB (default: 8 GiB).
# Environment variable overrides:
#   SWAP_THRESHOLD_GiB=<n>  change the RAM threshold          (default: 8)
#   SWAP_SIZE_MiB=<n>       change the swap size in MiB       (default: 8192)
#   FORCE_SWAP=1            always create swap                (ignores RAM)
#   FORCE_SWAP=0            never create swap                 (ignores RAM)
#
# Exports: ramMiB, swapSizeMiB, needSwap
detectRam() {
  local ramKiB ramGiB thresholdGiB
  ramKiB=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
  ramMiB=$(( ramKiB / 1024 ))
  ramGiB=$(( ramMiB / 1024 ))
  swapSizeMiB=${SWAP_SIZE_MiB:-8192}
  thresholdGiB=${SWAP_THRESHOLD_GiB:-8}

  info "Detected RAM: ${ramGiB} GiB (${ramMiB} MiB) — threshold: ${thresholdGiB} GiB"

  if [[ "${FORCE_SWAP:-}" == "1" ]]; then
    needSwap=1
    info "FORCE_SWAP=1 — swap creation forced regardless of RAM"
  elif [[ "${FORCE_SWAP:-}" == "0" ]]; then
    needSwap=0
    info "FORCE_SWAP=0 — swap creation disabled regardless of RAM"
  elif (( ramGiB < thresholdGiB )); then
    needSwap=1
    info "RAM (${ramGiB} GiB) below threshold — swap will be created (${swapSizeMiB} MiB)"
  else
    needSwap=0
    info "RAM (${ramGiB} GiB) meets threshold — swap not needed"
  fi
}

# ---------------------------------------------------------------------------
# Swap helpers
# ---------------------------------------------------------------------------

# Create a temporary swap on /mnt (already mounted by disko).
# - btrfs : uses mkswapfile (handles COW + mkswap in one step)
# - zfs   : creates a temporary zvol, mkswap + swapon
# - other : fallocate + mkswap
# Exports: swapFile (file path) or swapZvol (zvol name)
setupTempSwap() {
  swapFile="/mnt/.swapfile-install"
  swapZvol="zroot/swap-install"
  local mountFs
  mountFs=$(findmnt -n -o FSTYPE /mnt 2>/dev/null || true)

  if [[ -z "$mountFs" ]]; then
    warn "Could not detect filesystem on /mnt — skipping swap setup"
    return 1
  fi

  # Remove any stale temp swap from a prior failed run (file or zvol)
  rm -f "$swapFile" 2>/dev/null || true
  if zfs list -H "$swapZvol" &>/dev/null; then
    swapoff "/dev/zvol/$swapZvol" 2>/dev/null || true
    zfs destroy "$swapZvol" 2>/dev/null || true
  fi

  info "Filesystem on /mnt: ${mountFs} — creating ${swapSizeMiB} MiB swap"

  if [[ "$mountFs" == "btrfs" ]]; then
    if ! command -v btrfs &>/dev/null; then
      warn "btrfs command not found — cannot create swapfile, skipping"
      return 1
    fi
    run_command btrfs filesystem mkswapfile --size "${swapSizeMiB}M" "$swapFile"
    run_command swapon "$swapFile"
  elif [[ "$mountFs" == "zfs" ]]; then
    run_command zfs create -V "${swapSizeMiB}M" -o volblocksize=16384 "$swapZvol"
    run_command udevadm settle
    run_command mkswap "/dev/zvol/$swapZvol"
    run_command swapon "/dev/zvol/$swapZvol"
  else
    run_command fallocate -l "${swapSizeMiB}M" "$swapFile"
    run_command chmod 600 "$swapFile"
    run_command mkswap "$swapFile"
    run_command swapon "$swapFile"
  fi

  local swapTotal
  swapTotal=$(swapon --show=SIZE --noheadings | tr -d ' ' | paste -sd '+' || true)
  info "Swap activated — active swap: ${swapTotal}"
}

# swapoff all known swap devices (persistent zvol + temp file / zvol).
# Always safe — does not destroy anything.
# Used by EXIT trap (resilient to ^C).
deactivateSwap() {
  swapoff "/dev/zvol/zroot/swap"         2>/dev/null || true
  swapoff "/dev/zvol/zroot/swap-install" 2>/dev/null || true
  swapoff "/mnt/.swapfile-install"       2>/dev/null || true
}

# Destroy only the temporary swap devices (file + temp zvol).
# Only acts on devices that exist and are not persistent.
# Called after deactivateSwap, before nixos-enter.
destroyTempSwap() {
  if [[ -f "/mnt/.swapfile-install" ]]; then
    rm -f "/mnt/.swapfile-install" 2>/dev/null || true
  fi
  if zfs list -H "zroot/swap-install" &>/dev/null; then
    zfs destroy "zroot/swap-install" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# LUKS helpers
# ---------------------------------------------------------------------------

# Prompt the user to choose or generate a LUKS key file / key device.
# Exports: keyFile, addPassphrase, luksKeySize
setupLuksEncryption() {
  local generateKey keyStorage
  read -r -p "Do you want to generate a random key? [y/N]: " generateKey
  generateKey="${generateKey:-N}"

  if [[ "$generateKey" =~ ^[yY]$ ]]; then
    read -r -p "Store the key on a [f]ile or a raw [p]artition? [F/p]: " keyStorage
    keyStorage="${keyStorage:-F}"

    if [[ "$keyStorage" =~ ^[pP]$ ]]; then
      showDiskLsblk
      read -r -e -p "Enter the partition to use as key device (e.g. /dev/sdb): " keyFile
      info "Writing random key directly to ${keyFile}"
      warn "This will overwrite the first 4096 bytes of the device — save the key ASAP"
      sleep 5
      run_command dd if=/dev/urandom of=/tmp/temporary-keyFile.key bs=4096 count=1
      run_command chmod 400 /tmp/temporary-keyFile.key
      run_command dd if=/tmp/temporary-keyFile.key of="$keyFile" bs=4096 count=1
    else
      keyFile="/tmp/secret.key"
      info "Generating random key file at ${keyFile}"
      run_command dd if=/dev/urandom of="$keyFile" bs=4096 count=1
      run_command chmod 400 "$keyFile"
    fi
  else
    showDiskLsblk
    read -r -e -p "Enter path to existing key file or device [/tmp/secret.key]: " keyFile
    keyFile="${keyFile:-/tmp/secret.key}"
  fi

  read -r -p "Add a passphrase as a second LUKS key slot? [y/N]: " addPassphrase
  addPassphrase="${addPassphrase:-N}"

  if [[ "$addPassphrase" =~ ^[yY]$ ]]; then
    read -r -e -p "Enter the key size in bits [4096]: " luksKeySize
    luksKeySize="${luksKeySize:-4096}"
  fi
}

# Add a passphrase to a LUKS device using an existing key file.
# Usage: addLuksPassphrase <deviceDisk> <keyFile> <keySize>
addLuksPassphrase() {
  local deviceDisk="$1"
  local keyFile="$2"
  local keySize="${3:-4096}"
  local luksPartition

  luksPartition=$(blkid -t TYPE=crypto_LUKS -o device 2>/dev/null \
    | grep "^${deviceDisk}[0-9]" || true)

  if [[ -z "$luksPartition" ]]; then
    warn "No LUKS partition found on ${deviceDisk}"
    return 1
  fi

  info "Adding passphrase as a second LUKS key slot on ${luksPartition}"
  echo "You will be prompted to enter the new passphrase (twice for confirmation)."
  echo "The key file '${keyFile}' will be used to authenticate this operation."

  if run_command cryptsetup luksAddKey \
      --key-file "$keyFile" \
      --keyfile-size="$keySize" \
      "$luksPartition"; then
    printf '%b\n' "${GREEN}Passphrase successfully added to LUKS slot.${RESET}"
  else
    warn "Failed to add passphrase — continuing with key file only"
  fi
}

# ---------------------------------------------------------------------------
# Step functions — each corresponds to one entry in the STEPS array
# ---------------------------------------------------------------------------

step_interactive_setup() {
  if checkpoint_skip "STEP_INTERACTIVE_SETUP"; then
    return
  fi

  diskoEncrypted="N"
  diskoFs="btrfs"

  if [[ -e "/sys/firmware/efi/fw_platform_size" ]]; then
    echo "UEFI boot detected"

    read -r -p "Filesystem — [b]trfs or [z]fs? [B/z]: " fsChoice
    fsChoice="${fsChoice:-B}"
    if [[ "$fsChoice" =~ ^[zZ]$ ]]; then
      diskoFs="zfs"
      diskoEncrypted="N"
      diskoFile="$(pwd)/configurations/disko-configuration/current/disko-efi-zfs.nix"
      echo "Using ZFS filesystem (non-encrypted)"
    else
      diskoFs="btrfs"
      echo "Using btrfs filesystem"
      read -r -p "Use LUKS-encrypted device? [y/N]: " diskoEncrypted
      diskoEncrypted="${diskoEncrypted:-N}"
      if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
        diskoFile="$(pwd)/configurations/disko-configuration/current/disko-efi-luks-btrfs.nix"
        echo "Using encrypted LUKS configuration (btrfs)"
      else
        diskoFile="$(pwd)/configurations/disko-configuration/current/disko-efi-btrfs.nix"
        echo "Using standard (non-encrypted) btrfs configuration"
      fi
    fi
  else
    echo "BIOS boot detected — using disko-bios-btrfs configuration"
    diskoFile="$(pwd)/configurations/disko-configuration/current/disko-bios-btrfs.nix"
  fi

  showDiskLsblk
  echo ""
  read -r -e -p "Enter device to install NixOS on (e.g. /dev/sda, /dev/vda): " deviceDisk
  read -r -e -p "Enter size for the installation (e.g. 100% or 50G): "          sizeDisk

  echo -e "\nAvailable profiles:"
  nix "${nixFlags[@]}" flake show
  read -r -e -p "Enter the profile name to install: " nixosProfile
  echo -e "\n${nixosProfile} selected"

  printf '%b\n' "${YELLOW}/!\\ Starting installation in:${RESET}"
  for i in {5..1}; do
    printf '%b' "\r  ${CYAN}${i}${RESET} seconds... (Ctrl+C to cancel) "
    sleep 1
  done
  printf '%b\n' "\r  ${GREEN}Installing NixOS…${RESET}                    "

  checkpoint_set "VAR_DEVICE"          "$deviceDisk"
  checkpoint_set "VAR_SIZE"            "$sizeDisk"
  checkpoint_set "VAR_PROFILE"         "$nixosProfile"
  checkpoint_set "VAR_DISKO_FILE"      "$diskoFile"
  checkpoint_set "VAR_DISKO_FS"        "$diskoFs"
  checkpoint_set "VAR_DISKO_ENCRYPTED" "$diskoEncrypted"

  checkpoint_done "STEP_INTERACTIVE_SETUP"
}

step_luks_setup() {
  if [[ ! "${diskoEncrypted:-N}" =~ ^[yY]$ ]]; then
    return
  fi
  if checkpoint_skip "STEP_LUKS_SETUP"; then
    return
  fi
  setupLuksEncryption
  checkpoint_set "VAR_KEY_FILE"       "$keyFile"
  checkpoint_set "VAR_ADD_PASSPHRASE" "${addPassphrase:-N}"
  checkpoint_set "VAR_LUKS_KEY_SIZE"  "${luksKeySize:-4096}"
  checkpoint_done "STEP_LUKS_SETUP"
}

step_partition() {
  if checkpoint_skip "STEP_PARTITION"; then
    return
  fi
  info "Partitioning disk: ${deviceDisk}"
  local diskoArgs
  diskoArgs=(--argstr device "$deviceDisk" --argstr size "$sizeDisk")
  [[ "${diskoEncrypted:-N}" =~ ^[yY]$ ]] && diskoArgs+=(--argstr keyFile "$keyFile")

  run_command nix "${nixFlags[@]}" run \
    "nixpkgs/${nixpkgsRev}#disko" -- -m destroy,format,mount "$diskoFile" \
    "${diskoArgs[@]}"

  checkpoint_done "STEP_PARTITION"
}

step_zfs_tune() {
  if [[ "${diskoFs:-}" != "zfs" ]]; then
    return
  fi
  if checkpoint_skip "STEP_ZFS_TUNE"; then
    return
  fi
  local arcMaxGiB=${ZFS_ARC_MAX_GiB:-4}
  local arcMax=$(( arcMaxGiB * 1073741824 ))
  if [[ -w /sys/module/zfs/parameters/zfs_arc_max ]]; then
    info "Limiting ZFS ARC to ${arcMaxGiB} GiB"
    echo "$arcMax" > /sys/module/zfs/parameters/zfs_arc_max
  else
    warn "Cannot tune ZFS ARC — /sys/module/zfs/parameters/zfs_arc_max not writable"
  fi
  checkpoint_done "STEP_ZFS_TUNE"
}

step_luks_passphrase() {
  if [[ ! "${diskoEncrypted:-N}" =~ ^[yY]$ ]] || [[ ! "${addPassphrase:-N}" =~ ^[yY]$ ]]; then
    return
  fi
  if checkpoint_skip "STEP_LUKS_PASSPHRASE"; then
    return
  fi
  addLuksPassphrase "$deviceDisk" "$keyFile" "${luksKeySize:-4096}"
  checkpoint_done "STEP_LUKS_PASSPHRASE"
}

step_swap() {
  swapon "/dev/zvol/zroot/swap" 2>/dev/null || true

  if (( needSwap )); then
    if checkpoint_skip "STEP_SWAP"; then
      if [[ -f "/mnt/.swapfile-install" ]]; then
        swapon "/mnt/.swapfile-install" 2>/dev/null || true
      elif zfs list -H "zroot/swap-install" &>/dev/null; then
        swapon "/dev/zvol/zroot/swap-install" 2>/dev/null || true
      else
        info "Temporary swap was removed during the previous session — recreating it"
        setupTempSwap
      fi
    else
      setupTempSwap
      checkpoint_done "STEP_SWAP"
    fi
  fi
}

step_nixos_install() {
  if ! checkpoint_skip "STEP_NIXOS_INSTALL"; then
    info "Installing NixOS configuration: '${nixosProfile}'"
    run_command nixos-install --no-channel-copy --flake ".#${nixosProfile}" \
      --option extra-substituters        "https://attic.xuyh0120.win/lantian" \
      --option extra-trusted-public-keys "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    checkpoint_done "STEP_NIXOS_INSTALL"
  fi

  deactivateSwap
  destroyTempSwap
}

step_password() {
  if checkpoint_skip "STEP_PASSWORD"; then
    return
  fi
  if [[ -z "${userName:-}" ]]; then
    getDefaultUser 6
  fi
  checkpoint_set "VAR_USERNAME" "$userName"
  run_command nixos-enter --root /mnt -- passwd "$userName"
  checkpoint_done "STEP_PASSWORD"
}

step_copy_config() {
  if checkpoint_skip "STEP_COPY_CONFIG"; then
    return
  fi
  userName="${userName:-$(checkpoint_get "VAR_USERNAME")}"
  cd .. || exit 1
  run_command cp -r nixos-configuration "/mnt/home/${userName}"
  info "Changing owner of nixos-configuration to ${userName}"
  run_command chown -R 1000:100 "/mnt/home/${userName}/nixos-configuration"
  run_command git -C "/mnt/home/${userName}/nixos-configuration" config pull.rebase true

  checkpoint_done "STEP_COPY_CONFIG"
}

step_zfs_export() {
  if [[ "${diskoFs:-}" != "zfs" ]]; then
    return
  fi
  if checkpoint_skip "STEP_ZFS_EXPORT"; then
    return
  fi
  info "Exporting ZFS pool zroot for clean reboot"

  # Swap zvol must be off or zpool export fails (device busy)
  deactivateSwap

  cd /

  # Unmount everything under /mnt so the pool can be exported cleanly.
  umount -R /mnt 2>/dev/null || true

  # Retry loop with escalating measures (safety net if umount wasn't enough)
  local attempt=0
  while (( attempt < 3 )); do
    if zpool export -f zroot; then
      info "Pool zroot exported successfully — initrd will import it on first boot"
      checkpoint_done "STEP_ZFS_EXPORT"
      return
    fi

    (( attempt++ )) || true
    case "$attempt" in
      1)
        swapoff "/dev/zvol/zroot/swap"         2>/dev/null || true
        swapoff "/dev/zvol/zroot/swap-install" 2>/dev/null || true
        sleep 1
        ;;
      2)
        warn "Still blocked — killing processes and using lazy unmount"
        fuser -km /mnt 2>/dev/null || true
        sleep 1
        umount -l /mnt 2>/dev/null || true
        sleep 1
        ;;
    esac
  done

  warn "Still could not export zroot — first boot may fail to import the pool"
  warn "Recovery from the live CD:"
  warn "  fuser -km /mnt"
  warn "  umount -R /mnt"
  warn "  zpool export -f zroot"
  warn "  reboot"
  # Not marking done so the user can retry with --step ZFS_EXPORT
}

# ---------------------------------------------------------------------------
# Main install function
# ---------------------------------------------------------------------------

nixosInstallFn() {
  sleep 1
  trap 'deactivateSwap' EXIT

  # --- Root check (must happen before anything else) ----------------------
  if [[ $EUID -ne 0 ]]; then
    warn "This script must be run as root or with sudo"
    echo "Please run: sudo $0"
    echo "Stopped (Error 1)"
    exit 1
  fi

  # --- Standalone step mode ------------------------------------------------
  if [[ -n "${ONLY_STEP:-}" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
      warn "State file not found at ${STATE_FILE}"
      warn "A full install must complete at least STEP_INTERACTIVE_SETUP first"
      exit 1
    fi
    validate_step "$ONLY_STEP"
    load_step_state
    detectRam
    "$(step_func "$ONLY_STEP")"
    trap - EXIT
    return
  fi

  # --- Normal flow ----------------------------------------------------------
  checkpoint_resume_prompt

  if [[ "${RESUMING:-0}" == "1" ]]; then
    load_step_state
  fi

  detectRam

  for step in "${STEPS[@]}"; do
    "$(step_func "$step")"
  done

  checkpoint_clear
  trap - EXIT
  info "Installation complete! Please reboot to use NixOS."
}
