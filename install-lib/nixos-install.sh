### nixos-install.sh — NixOS installation on a bare machine
### Sourced by install.sh; requires lib.sh to be sourced first.
# shellcheck shell=bash

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

# Create a temporary swap file on /mnt (already mounted by disko).
# btrfs needs btrfs filesystem mkswapfile; all other filesystems use fallocate.
# Exports: swapFile
setupTempSwap() {
  swapFile="/mnt/.swapfile-install"
  local mountFs
  mountFs=$(findmnt -n -o FSTYPE /mnt 2>/dev/null || true)

  if [[ -z "$mountFs" ]]; then
    warn "Could not detect filesystem on /mnt — skipping swap setup"
    return 1
  fi

  info "Filesystem on /mnt: ${mountFs} — creating ${swapSizeMiB} MiB swap at ${swapFile}"

  if [[ "$mountFs" == "btrfs" ]]; then
    # btrfs mkswapfile handles COW disable + mkswap in one step (btrfs-progs >= 6.1)
    run_command btrfs filesystem mkswapfile --size "${swapSizeMiB}M" "$swapFile"
  else
    run_command fallocate -l "${swapSizeMiB}M" "$swapFile"
    run_command chmod 600 "$swapFile"
    run_command mkswap "$swapFile"
  fi

  run_command swapon "$swapFile"

  local swapTotal
  swapTotal=$(swapon --show=SIZE --noheadings | tr -d ' ' | paste -sd '+' || true)
  info "Swap activated — active swap: ${swapTotal}"
}

# Deactivate and delete the temporary swap file.
# No-op when swapFile is unset or the file no longer exists.
teardownTempSwap() {
  if [[ -n "${swapFile:-}" && -f "${swapFile}" ]]; then
    info "Removing temporary swap file: ${swapFile}"
    run_command swapoff "$swapFile"
    run_command rm -f "$swapFile"
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
# Main install function
# ---------------------------------------------------------------------------

nixosInstallFn() {
  sleep 1
  trap 'teardownTempSwap' EXIT

  # --- Root check (must happen before anything else) ----------------------
  if [[ $EUID -ne 0 ]]; then
    warn "This script must be run as root or with sudo"
    echo "Please run: sudo $0"
    echo "Stopped (Error 1)"
    exit 1
  fi

  # --- Resume prompt -------------------------------------------------------
  # If STATE_FILE exists the user is offered to resume where they left off.
  # RESUMING=1 means we reload persisted variables and skip completed steps.
  checkpoint_resume_prompt

  # --- Restore persisted variables on resume -------------------------------
  # These are only populated when RESUMING=1; on a fresh run they stay empty
  # until the interactive-setup step fills and saves them.
  if [[ "${RESUMING:-0}" == "1" ]]; then
    deviceDisk="$(checkpoint_get   "VAR_DEVICE")"
    sizeDisk="$(checkpoint_get     "VAR_SIZE")"
    nixosProfile="$(checkpoint_get "VAR_PROFILE")"
    diskoFile="$(checkpoint_get    "VAR_DISKO_FILE")"
    diskoEncrypted="$(checkpoint_get "VAR_DISKO_ENCRYPTED")"
    keyFile="$(checkpoint_get      "VAR_KEY_FILE")"
    addPassphrase="$(checkpoint_get "VAR_ADD_PASSPHRASE")"
    luksKeySize="$(checkpoint_get  "VAR_LUKS_KEY_SIZE")"
    userName="$(checkpoint_get     "VAR_USERNAME")"
  fi

  # --- RAM detection (fast, always run) ------------------------------------
  detectRam

  # --- Step: interactive setup ---------------------------------------------
  # Asks the user for boot mode, encryption, disk, size, and profile.
  # On resume this whole block is skipped because all answers were saved.
  if ! checkpoint_skip "STEP_INTERACTIVE_SETUP"; then

    # Initialise diskoEncrypted to a safe default before the UEFI/BIOS branch
    # so it is never unset when referenced later (guards against set -u).
    diskoEncrypted="N"

    if [[ -e "/sys/firmware/efi/fw_platform_size" ]]; then
      echo "UEFI boot detected — using disko-efi-btrfs configuration"

      read -r -p "Use LUKS-encrypted device? [y/N]: " diskoEncrypted
      diskoEncrypted="${diskoEncrypted:-N}"

      if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
        diskoFile="$(pwd)/configurations/disko-configuration/current/disko-efi-luks-btrfs.nix"
        echo "Using encrypted LUKS configuration"
      else
        diskoFile="$(pwd)/configurations/disko-configuration/current/disko-efi-btrfs.nix"
        echo "Using standard (non-encrypted) configuration"
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

    # Countdown before the point of no return
    printf '%b\n' "${YELLOW}/!\\ Starting installation in:${RESET}"
    for i in {5..1}; do
      printf '%b' "\r  ${CYAN}${i}${RESET} seconds... (Ctrl+C to cancel) "
      sleep 1
    done
    printf '%b\n' "\r  ${GREEN}Installing NixOS…${RESET}                    "

    # Persist all interactive answers so they survive a crash
    checkpoint_set "VAR_DEVICE"          "$deviceDisk"
    checkpoint_set "VAR_SIZE"            "$sizeDisk"
    checkpoint_set "VAR_PROFILE"         "$nixosProfile"
    checkpoint_set "VAR_DISKO_FILE"      "$diskoFile"
    checkpoint_set "VAR_DISKO_ENCRYPTED" "$diskoEncrypted"

    checkpoint_done "STEP_INTERACTIVE_SETUP"
  fi

  # --- Step: LUKS key setup ------------------------------------------------
  # Only entered when the user chose encryption during interactive setup.
  # On resume the key path and passphrase choice are restored from state.
  if [[ "${diskoEncrypted:-N}" =~ ^[yY]$ ]]; then
    if ! checkpoint_skip "STEP_LUKS_SETUP"; then
      setupLuksEncryption
      # Persist LUKS variables so the partition step can use them on resume
      checkpoint_set "VAR_KEY_FILE"      "$keyFile"
      checkpoint_set "VAR_ADD_PASSPHRASE" "${addPassphrase:-N}"
      checkpoint_set "VAR_LUKS_KEY_SIZE"  "${luksKeySize:-4096}"
      checkpoint_done "STEP_LUKS_SETUP"
    fi
  fi

  # --- Step: disk partitioning with disko ----------------------------------
  # This is destructive — it formats the target disk.
  # Skipped on resume if it completed successfully before the crash.
  if ! checkpoint_skip "STEP_PARTITION"; then
    info "Partitioning disk: ${deviceDisk}"
    local diskoArgs
    diskoArgs=(--argstr device "$deviceDisk" --argstr size "$sizeDisk")
    [[ "${diskoEncrypted:-N}" =~ ^[yY]$ ]] && diskoArgs+=(--argstr keyFile "$keyFile")

    run_command nix "${nixFlags[@]}" run \
      "nixpkgs/${nixpkgsRev}#disko" -- -m destroy,format,mount "$diskoFile" \
      "${diskoArgs[@]}"

    checkpoint_done "STEP_PARTITION"
  fi

  # --- Step: optional LUKS passphrase slot ---------------------------------
  if [[ "${diskoEncrypted:-N}" =~ ^[yY]$ ]] && [[ "${addPassphrase:-N}" =~ ^[yY]$ ]]; then
    if ! checkpoint_skip "STEP_LUKS_PASSPHRASE"; then
      addLuksPassphrase "$deviceDisk" "$keyFile" "${luksKeySize:-4096}"
      checkpoint_done "STEP_LUKS_PASSPHRASE"
    fi
  fi

  # --- Step: temporary swap ------------------------------------------------
  # Created on /mnt (now mounted by disko) when RAM is below the threshold.
  # nixos-install can be memory-hungry during flake evaluation.
  if (( needSwap )); then
    if checkpoint_skip "STEP_SWAP"; then
      if [[ ! -f "/mnt/.swapfile-install" ]]; then
        info "Temporary swap was removed during the previous session — recreating it"
        setupTempSwap
      fi
    else
      setupTempSwap
      checkpoint_done "STEP_SWAP"
    fi
  fi

  # --- Step: nixos-install -------------------------------------------------
  # The main installation step — most likely place for a failure.
  if ! checkpoint_skip "STEP_NIXOS_INSTALL"; then
    info "Installing NixOS configuration: '${nixosProfile}'"
    run_command nixos-install --no-channel-copy --flake ".#${nixosProfile}" \
      --option extra-substituters        "https://attic.xuyh0120.win/lantian" \
      --option extra-trusted-public-keys "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    checkpoint_done "STEP_NIXOS_INSTALL"
  fi

  # Always attempt swap teardown — idempotent, safe to call even if swap was
  # not set up (the function checks for the file before acting).
  teardownTempSwap

  # --- Step: user password -------------------------------------------------
  if ! checkpoint_skip "STEP_PASSWORD"; then
    # Restore userName from state if we are resuming and it was already set
    if [[ -z "${userName:-}" ]]; then
      getDefaultUser 6
    fi
    checkpoint_set "VAR_USERNAME" "$userName"
    run_command nixos-enter --root /mnt -- passwd "$userName"
    checkpoint_done "STEP_PASSWORD"
  fi

  # --- Step: copy configuration into the new system's home -----------------
  if ! checkpoint_skip "STEP_COPY_CONFIG"; then
    # Make sure userName is set even on a partial resume where STEP_PASSWORD
    # was already done but STEP_COPY_CONFIG was not.
    userName="${userName:-$(checkpoint_get "VAR_USERNAME")}"

    cd .. || exit 1
    run_command cp -r nixos-configuration "/mnt/home/${userName}"
    info "Changing owner of nixos-configuration to ${userName}"
    run_command chown -R 1000:100 "/mnt/home/${userName}/nixos-configuration"
    run_command git -C "/mnt/home/${userName}/nixos-configuration" config pull.rebase true

    checkpoint_done "STEP_COPY_CONFIG"
  fi

  # --- All steps completed — clean up state --------------------------------
    checkpoint_clear
    trap - EXIT
  info "Installation complete! Please reboot to use NixOS."
}
