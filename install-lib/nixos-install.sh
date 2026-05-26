### Install script for NixOS systems

showDiskLsblk(){
  echo "Available block devices:"
  lsblk -d -n -o NAME,SIZE,TYPE | grep -E '^(sd|vd|nvme|hd)' || true
}

# Detect total RAM and decide whether a temporary swap is needed
# Swap is created when RAM < SWAP_THRESHOLD_GiB (default: 4 GiB)
# Override behaviour via environment variables:
#   SWAP_THRESHOLD_GiB=<n>  — change the RAM threshold (default: 4)
#   SWAP_SIZE_MiB=<n>       — change the swap size in MiB (default: 8192)
#   FORCE_SWAP=1            — always create swap regardless of RAM
#   FORCE_SWAP=0            — never create swap regardless of RAM
# Usage: detectRam
# Exports: ramMiB, swapSizeMiB, needSwap
detectRam() {
  ramKiB=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
  ramMiB=$(( ramKiB / 1024 ))
  ramGiB=$(( ramMiB / 1024 ))
  swapSizeMiB=${SWAP_SIZE_MiB:-8192}  # fixed 8 GiB by default — overridable via SWAP_SIZE_MiB

  ### Default threshold: 4 GiB — overridable via SWAP_THRESHOLD_GiB
  local thresholdGiB=${SWAP_THRESHOLD_GiB:-4}

  info "Detected RAM: ${ramGiB} GiB (${ramMiB} MiB) — threshold: ${thresholdGiB} GiB"

  ### Determine whether swap is needed, with optional env var overrides
  if [[ "${FORCE_SWAP:-}" == "1" ]]; then
    needSwap=1
    info "FORCE_SWAP=1 — swap creation forced regardless of RAM"
  elif [[ "${FORCE_SWAP:-}" == "0" ]]; then
    needSwap=0
    info "FORCE_SWAP=0 — swap creation disabled regardless of RAM"
  elif (( ramGiB < thresholdGiB )); then
    needSwap=1
    info "RAM (${ramGiB} GiB) is below threshold (${thresholdGiB} GiB) — swap will be created (${swapSizeMiB} MiB)"
  else
    needSwap=0
    info "RAM (${ramGiB} GiB) meets or exceeds threshold (${thresholdGiB} GiB) — swap not needed"
  fi
}

# Create a temporary swapfile on /mnt (already mounted by disko)
# Handles btrfs (needs truncate + chattr +C) vs other filesystems (fallocate)
# Usage: setupTempSwap
# Exports: swapFile
setupTempSwap() {
  swapFile="/mnt/.swapfile-install"

  ### Detect filesystem type of /mnt
  mountFs=$(findmnt -n -o FSTYPE /mnt 2>/dev/null || true)

  if [[ -z "$mountFs" ]]; then
    warn "Could not detect filesystem on /mnt, skipping swap setup"
    return 1
  fi

  info "Filesystem on /mnt: $mountFs — creating ${swapSizeMiB} MiB swapfile at $swapFile"

  if [[ "$mountFs" == "btrfs" ]]; then
    ### btrfs: use mkswapfile which handles COW disable and swap init in one step
    ### requires btrfs-progs >= 6.1
    run_command btrfs filesystem mkswapfile --size "${swapSizeMiB}M" "$swapFile"
  else
    ### ext4, xfs, etc.: fallocate is sufficient and much faster
    run_command fallocate -l "${swapSizeMiB}M" "$swapFile"
    run_command chmod 600 "$swapFile"
    run_command mkswap "$swapFile"
  fi

  run_command swapon "$swapFile"

  ### Confirmation
  swapTotal=$(swapon --show=SIZE --noheadings | tr -d ' ' | paste -sd '+' || true)
  info "Swap activated — active swap: ${swapTotal}"
}

# Deactivate and remove the temporary swapfile after installation
# Usage: teardownTempSwap
teardownTempSwap() {
  if [[ -n "${swapFile:-}" && -f "${swapFile:-}" ]]; then
    info "Removing temporary swapfile $swapFile"
    run_command swapoff "$swapFile"
    run_command rm -f "$swapFile"
  fi
}

# Prompt the user for LUKS key file and optional passphrase
# Usage: setupLuksEncryption
# Exports: keyFile, addPassphrase
setupLuksEncryption() {
  read -p "Do you want to generate a random key? [y/N]: " generateKey
  generateKey=${generateKey:-N}

  if [[ "$generateKey" =~ ^[yY]$ ]]; then
    read -p "Store the key on a [f]ile or a raw [p]artition? [F/p]: " keyStorage
    keyStorage=${keyStorage:-F}

    if [[ "$keyStorage" =~ ^[pP]$ ]]; then
      showDiskLsblk
      read -ep "Enter the partition to use as key device (e.g. /dev/sdb): " keyFile
      info "Writing random key to $keyFile"
      warn "This action will replace the actual keyfile installed in devices, save it ASAP"
      sleep 5
     
      echo "Adding keyfile to $keyFile device"
      ### Create a temporary keyFile and install it in partition or full device
      run_command dd if=/dev/urandom of=/tmp/temporary-keyFile.key bs=4096 count=1
      echo "Apply permission to avoid non root user to see it"
      run_command chmod 400 /tmp/temporary-keyFile.key
      echo "Apply keyfile directly on $keyFile"
      run_command dd if=/tmp/temporary-keyFile.key of="$keyFile" bs=4096 count=1
    else
      keyFile="/tmp/secret.key"
      info "Generating random key file at $keyFile"
      run_command dd if=/dev/urandom of="$keyFile" bs=4096 count=1
      run_command chmod 400 "$keyFile"
    fi

  else
    showDiskLsblk
    read -ep "Enter path to existing key file or device [/tmp/secret.key]: " keyFile
    keyFile=${keyFile:-/tmp/secret.key}
  fi

  read -p "Do you want to add a passphrase as a second LUKS key slot ? [y/N]: " addPassphrase
  addPassphrase=${addPassphrase:-N}

  if [[ "$addPassphrase" =~ ^[yY]$ ]]; then
    read -ep "Enter the key size in bits [4096]: " luksKeySize
    luksKeySize=${luksKeySize:-4096}
  fi
}

# Add a passphrase to a LUKS key slot using an existing key file
# Usage: addLuksPassphrase <deviceDisk> <keyFile> <keySize>
addLuksPassphrase() {
  local deviceDisk="$1"
  local keyFile="$2"
  local keySize="${3:-4096}"

  local luksPartition
  luksPartition=$(blkid -t TYPE=crypto_LUKS -o device 2>/dev/null | grep "^${deviceDisk}[0-9]" || true)

  if [[ -z "$luksPartition" ]]; then
    warn "No LUKS partition found on $deviceDisk"
    return 1
  fi

  echo ""
  info "Adding passphrase as a second LUKS key slot on $luksPartition"
  echo "You will be prompted to enter the new passphrase (twice for confirmation)."
  echo "The key file '$keyFile' will be used to authenticate this operation."

  if run_command cryptsetup luksAddKey --key-file "$keyFile" --keyfile-size="$keySize" "$luksPartition"; then
    echo -e "${GREEN}Passphrase successfully added to LUKS slot.${RESET}"
  else
    warn "Failed to add passphrase. Continuing with keyfile only"
  fi
}

nixosInstallFn() {
  sleep 1
  ### Test if run with sudo or root
  if [[ $EUID -ne 0 ]]; then
    warn "You're not run this script with sudo or root"
    echo "Please run 'sudo $0' instead or '$0' as root"
    echo "Stopped at sudo test (Error 1)"
    exit 1
  fi

  ### Detect RAM early (used later for swap sizing)
  detectRam

  ### Partitionning the disk with disko
  # Get info if the host is UEFI or BIOS (boot method)
  diskoEncrypted="N"  # default value — must be initialized before the if block (guards against -u)

  if [[ -e "/sys/firmware/efi/fw_platform_size" ]]; then
    echo "Your pc use UEFI method to boot, continuing with 'disko-efi-btrfs' nix expression"

    read -p "Do you want to use luks encrypted device ? [y/N]: " diskoEncrypted
    diskoEncrypted=${diskoEncrypted:-N} # Set "N" as a default value (${variable:-default})

    ### condition for encryption choice
    if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
        diskoFile=$(pwd)/configurations/disko-configuration/current/disko-efi-luks-btrfs.nix
        echo "Using encrypted LUKS configuration"
    else
        diskoFile=$(pwd)/configurations/disko-configuration/current/disko-efi-btrfs.nix
        echo "Using standard (non-encrypted) configuration"
    fi

  else
    echo "Your pc use BIOS method to boot, continuing with 'disko-bios-btrfs' nix expression"
    diskoFile=$(pwd)/configurations/disko-configuration/current/disko-bios-btrfs.nix
  fi

  showDiskLsblk

  echo ""
  read -ep "Enter device to install NixOS (like /dev/sda, /dev/vda...): " deviceDisk
  read -ep "Enter size of your new installation (like 100% or 50G): " sizeDisk
  info "Prepare $deviceDisk for installing"
  sleep 1

  echo -e "\nProfile available:"
  nix "${nixFlags[@]}" flake show

  read -ep "Enter name of profile to install: " nixosProfile

  echo -e "\n$nixosProfile selected to install"

  echo -e "${YELLOW}/!\ Starting installation in:${RESET}"
  for i in {5..1}; do
    echo -ne "\r  ${CYAN}$i${RESET} seconds... (Ctrl+C to cancel) "
    sleep 1
  done
  echo -e "\r  ${GREEN} - Installing NixOS conf${RESET}                    \n"

  info "Partitionning disk"
  diskoArgs=(--argstr device "$deviceDisk" --argstr size "$sizeDisk") # Dynamic args for disko

  if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
    setupLuksEncryption
    diskoArgs+=(--argstr keyFile "$keyFile")
  fi

  run_command nix "${nixFlags[@]}" run \
    nixpkgs/$nixpkgsRev#disko -- -m destroy,format,mount $diskoFile \
    "${diskoArgs[@]}"

  if [[ "$diskoEncrypted" =~ ^[yY]$ ]] && [[ "${addPassphrase:-N}" =~ ^[yY]$ ]]; then
    addLuksPassphrase "$deviceDisk" "$keyFile" "${luksKeySize:-4096}"
  fi

  ### Setup temporary swap on /mnt (now mounted by disko) before nixos-install
  ### nixos-install can be very RAM-hungry during flake evaluation
  if (( needSwap )); then
    setupTempSwap
  fi

  sleep 1
  echo ""
  info "installing NixOS configuration with this profile: '$nixosProfile'"
  run_command nixos-install --no-channel-copy --flake .#$nixosProfile \
    --option extra-substituters "https://attic.xuyh0120.win/lantian" \
    --option extra-trusted-public-keys "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="

  ### Cleanup swap after installation (no-op if swap was not created)
  teardownTempSwap

  ### Set user password via nixos-enter
  getDefaultUser 6
  info "Setting password for $userName via nixos-enter"
  run_command nixos-enter --root /mnt -- passwd "$userName"

  info "The configuration will be copied in your home folder"

  cd .. || exit 1
    run_command cp -r nixos-configuration /mnt/home/$userName
    info "change owner of the dirctory of nixos-configuration"
    run_command chown -R 1000:100 /mnt/home/$userName/nixos-configuration
    run_command git -C /mnt/home/$userName/nixos-configuration config pull.rebase true
  
  info "Installation Completed ! Please reboot to use NixOS"
}
