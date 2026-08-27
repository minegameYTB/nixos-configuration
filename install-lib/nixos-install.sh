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
  # ZFS ARC is capped BEFORE partitioning so it also protects the
  # disko layout/mount phase (which happens under STEP_PARTITION).
  "STEP_ZFS_TUNE"
  "STEP_PARTITION"
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
  echo "Available block devices (device, size, model, reproducible by-id path):"
  for disk in $(lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|hd|mmcblk)'); do
    size=$(lsblk -d -n -o SIZE "/dev/$disk")
    model=$(lsblk -d -n -o MODEL "/dev/$disk" 2>/dev/null | xargs)
    # first whole-disk /dev/disk/by-id name (partitions excluded via the $ anchor)
    # shellcheck disable=SC2012 # ls -l is the readable way to resolve symlink names here
    byid=$(ls -l /dev/disk/by-id/ 2>/dev/null | awk -v d="$disk" '$NF ~ ("/"d"$") {print $9}' | head -1)
    printf '  /dev/%-14s %-9s %-28s %s\n' "$disk" "$size" "$model" "${byid:+/dev/disk/by-id/$byid}"
  done
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
# - other : fallocate + mkswap
setupTempSwap() {
  swapFile="/mnt/.swapfile-install"
  local mountFs
  mountFs=$(findmnt -n -o FSTYPE /mnt 2>/dev/null || true)

  if [[ -z "$mountFs" ]]; then
    warn "Could not detect filesystem on /mnt — skipping swap setup"
    return 1
  fi

  # Remove any stale temp swap file from a prior failed run
  rm -f "$swapFile" 2>/dev/null || true

  info "Filesystem on /mnt: ${mountFs} — creating ${swapSizeMiB} MiB swap"

  if [[ "$mountFs" == "btrfs" ]]; then
    if ! command -v btrfs &>/dev/null; then
      warn "btrfs command not found — cannot create swapfile, skipping"
      return 1
    fi
    run_command btrfs filesystem mkswapfile --size "${swapSizeMiB}M" "$swapFile"
    run_command swapon "$swapFile"
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

# swapoff all known swap devices.
# Always safe — does not destroy anything.
# Used by EXIT trap (resilient to ^C).
deactivateSwap() {
  swapoff "/mnt/.swapfile-install" 2>/dev/null || true
}

# Destroy only the temporary swap file.
# Only acts if the file exists.
# Called after deactivateSwap, before nixos-enter.
destroyTempSwap() {
  if [[ -f "/mnt/.swapfile-install" ]]; then
    rm -f "/mnt/.swapfile-install" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# LUKS helpers
# ---------------------------------------------------------------------------

# Generate the LUKS key using pre-set choices (prompts handled in step_interactive_setup).
# Reads from checkpoint: keyFile
# For partition storage: writes key to the partition + keeps a temp copy in /tmp
# For file storage:     writes key directly to the file
setupLuksEncryption() {
  if [[ -f "$keyFile" || -b "$keyFile" ]]; then
    info "Key already exists at ${keyFile} — skipping generation"
    return
  fi

  info "Generating random LUKS key ..."
  local tmpKey="/tmp/temporary-keyFile.key"
  run_command dd if=/dev/urandom of="$tmpKey" bs=4096 count=1
  run_command chmod 400 "$tmpKey"
  run_command dd if="$tmpKey" of="$keyFile" bs=4096 count=1

  if [[ ! -b "$keyFile" ]]; then
    mv "$tmpKey" "$keyFile" 2>/dev/null || cp "$tmpKey" "$keyFile"
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
    | grep "^${deviceDisk}p\?[0-9]" || true)

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

# Resolve the uid:gid of the target user inside the mounted system, so the
# copied configuration is owned by the right account instead of a hardcoded
# 1000:100.  Falls back to 1000:100 when the user cannot be queried.
# Usage: uidGid=$(target_uid_gid <userName>)   → prints "uid:gid"
target_uid_gid() {
  local user="$1" uid gid
  uid=$(nixos-enter --root /mnt -- id -u "$user" 2>/dev/null || true)
  gid=$(nixos-enter --root /mnt -- id -g "$user" 2>/dev/null || true)
  if [[ -n "$uid" && -n "$gid" ]] && [[ "$uid" =~ ^[0-9]+$ ]] && [[ "$gid" =~ ^[0-9]+$ ]]; then
    echo "${uid}:${gid}"
  else
    echo "1000:100"
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
      diskoFile="$INSTALL_DIR/configurations/disko-configuration/current/disko-efi-zfs.nix"
      echo "Using ZFS filesystem"
    else
      diskoFs="btrfs"
      echo "Using btrfs filesystem"
      read -r -p "Use LUKS-encrypted device? [y/N]: " diskoEncrypted
      diskoEncrypted="${diskoEncrypted:-N}"
      if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
        diskoFile="$INSTALL_DIR/configurations/disko-configuration/current/disko-efi-luks-btrfs.nix"
        echo "Using encrypted LUKS configuration (btrfs)"
      else
        diskoFile="$INSTALL_DIR/configurations/disko-configuration/current/disko-efi-btrfs.nix"
        echo "Using standard (non-encrypted) btrfs configuration"
      fi
    fi
  else
    echo "BIOS boot detected — using disko-bios-btrfs configuration"
    diskoFile="$INSTALL_DIR/configurations/disko-configuration/current/disko-bios-btrfs.nix"
  fi

  showDiskLsblk
  echo ""
  read -r -e -p "Enter device to install NixOS on (e.g. /dev/vda or /dev/disk/by-id/...): " deviceDisk
  read -r -e -p "Enter size for the installation (e.g. 100% or 50G): "          sizeDisk

  echo "Available installable profiles (name - root fs):"
  # shellcheck disable=SC2016 # the Nix expression is intentionally single-quoted
  nix "${nixFlags[@]}" eval --raw ".#nixosConfigurations" --apply '
    cfgs:
    builtins.concatStringsSep "\n" (
      builtins.map
        (name: "  ${name} - ${(cfgs.${name}.config.fileSystems."/" or { fsType = "?"; }).fsType}")
        (builtins.filter (name: builtins.match "(iso|recovery)-.*" name == null) (builtins.attrNames cfgs))
    )
  ' || warn "Could not list profiles — type the profile name manually"
  echo ""
  read -r -e -p "Enter the profile name to install: " nixosProfile
  echo "${nixosProfile} selected"

  # ── username ──
  getDefaultUser 6

  # ── LUKS prompts (only if encryption was chosen above) ──
  if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
    local generateKey keyStorage
    read -r -p "Do you want to generate a random key? [y/N]: " generateKey
    generateKey="${generateKey:-N}"

    if [[ "$generateKey" =~ ^[yY]$ ]]; then
      read -r -p "Store the key on a [f]ile or a raw [p]artition? [F/p]: " keyStorage
      keyStorage="${keyStorage:-F}"
      if [[ "$keyStorage" =~ ^[pP]$ ]]; then
        showDiskLsblk
        read -r -e -p "Enter the partition to use as key device (e.g. /dev/sdb): " keyFile
      else
        keyFile="/tmp/secret.key"
      fi
    else
      showDiskLsblk
      read -r -e -p "Enter path to existing key file or device [/tmp/secret.key]: " keyFile
      keyFile="${keyFile:-/tmp/secret.key}"
    fi

    # The key device must not live on the disk being installed: disko will
    # wipe it during STEP_PARTITION, destroying the key.
    if [[ "$keyFile" == "$deviceDisk"* ]] || [[ "$keyFile" == "${deviceDisk}p"* ]]; then
      warn "The key device '${keyFile}' is on the same disk as the installation target (${deviceDisk})"
      warn "It will be destroyed by partitioning — use a separate device (e.g. another disk or SD card)"
    fi

    read -r -p "Add a passphrase as a second LUKS key slot? [y/N]: " addPassphrase
    addPassphrase="${addPassphrase:-N}"
    if [[ "$addPassphrase" =~ ^[yY]$ ]]; then
      read -r -e -p "Enter the key size in bits [4096]: " luksKeySize
      luksKeySize="${luksKeySize:-4096}"
    fi

    checkpoint_set "VAR_KEY_FILE"       "$keyFile"
    checkpoint_set "VAR_ADD_PASSPHRASE" "$addPassphrase"
    checkpoint_set "VAR_LUKS_KEY_SIZE"  "${luksKeySize:-4096}"
  fi

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
  checkpoint_set "VAR_USERNAME"        "$userName"

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
  checkpoint_done "STEP_LUKS_SETUP"
}

step_partition() {
  if checkpoint_skip "STEP_PARTITION"; then
    return
  fi
  info "Partitioning disk: ${deviceDisk}"
  local diskoArgs
  diskoArgs=(--argstr device "$deviceDisk" --argstr size "$sizeDisk")
  if [[ "${diskoEncrypted:-N}" =~ ^[yY]$ ]]; then
    diskoArgs+=(--argstr keyFile "$keyFile")
  fi

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
  local arcMaxGiB=${ZFS_ARC_MAX_GiB:-1}
  local arcMax=$(( arcMaxGiB * 1073741824 ))
  # Ensure the zfs module is loaded so the runtime cap applies from the
  # very start (this step now runs BEFORE disko partitioning).
  modprobe zfs 2>/dev/null || true
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
  # ZFS does not support swap files (removed in "zfs: remove swap on zfs").
  # On ZFS the disko config provides no swap — skipping keeps low-RAM ZFS
  # installs from aborting on an invalid swapon.
  if [[ "${diskoFs:-}" == "zfs" ]]; then
    info "ZFS detected — temporary swap skipped (swap files unsupported on ZFS)"
    return
  fi

  if (( needSwap )); then
    if checkpoint_skip "STEP_SWAP"; then
      if [[ -f "/mnt/.swapfile-install" ]]; then
        swapon "/mnt/.swapfile-install" 2>/dev/null || true
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
  userName="${userName:-$(checkpoint_get "VAR_USERNAME")}"
  run_command nixos-enter --root /mnt -- passwd "$userName"
  checkpoint_done "STEP_PASSWORD"
}

step_copy_config() {
  if checkpoint_skip "STEP_COPY_CONFIG"; then
    return
  fi
  userName="${userName:-$(checkpoint_get "VAR_USERNAME")}"
  local targetDir="/mnt/home/${userName}/nixos-configuration"
  local sourceDir owner
  sourceDir="${INSTALL_DIR:-$(cd "$(dirname "$0")" && pwd)}"
  owner="$(target_uid_gid "$userName")"

  if [[ -d "${sourceDir}/.git" ]]; then
    run_command cp -r "$sourceDir" "$targetDir"
    run_command chown -R "$owner" "$targetDir"
    run_command git -C "$targetDir" config pull.rebase true
  else
    local repoUrl="${INSTALL_REPO_URL:-}"
    local repoRev=""
    if [[ -z "$repoUrl" && -f "${sourceDir}/.config-repo" ]]; then
      read -r repoUrl repoRev < "${sourceDir}/.config-repo"
    fi
    if [[ -z "$repoUrl" && -f "${sourceDir}/lib/repo.nix" ]]; then
      repoUrl=$(sed -n 's/.*url *= *"\(.*\)";/\1/p' "${sourceDir}/lib/repo.nix" | head -1)
    fi
    if [[ -n "$repoUrl" && -n "$repoRev" ]]; then
      info "Cloning repository (full history) from ${repoUrl}"
      run_command git clone --no-checkout "$repoUrl" "$targetDir"
      run_command git -C "$targetDir" checkout "$repoRev"
      run_command chown -R "$owner" "$targetDir"
      run_command git -C "$targetDir" config pull.rebase true
    elif [[ -n "$repoUrl" ]]; then
      info "Cloning repository (shallow) from ${repoUrl}"
      run_command git clone --depth 1 "$repoUrl" "$targetDir"
      run_command chown -R "$owner" "$targetDir"
      run_command git -C "$targetDir" config pull.rebase true
    else
      warn "No .git or repo URL found — copying without history"
      run_command cp -r "${sourceDir}" "$targetDir"
      run_command chown -R "$owner" "$targetDir"
    fi
  fi
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
        warn "Still blocked — killing processes and using lazy unmount"
        fuser -km /mnt 2>/dev/null || true
        sleep 1
        umount -l /mnt 2>/dev/null || true
        sleep 1
        ;;
      2)
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

  # --- Root check (safety net — install.sh should auto-elevate before dispatch)
  if [[ $EUID -ne 0 ]]; then
    warn "This script must be run as root."
    echo "Please run install.sh without sudo — it will auto-elevate after the version check."
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
