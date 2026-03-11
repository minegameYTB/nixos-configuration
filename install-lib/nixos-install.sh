#!/usr/bin/env bash

### Install script for NixOS systems

# Prompt the user for LUKS key file and optional passphrase
# Usage: setupLuksEncryption
# Exports: keyFile, addPassphrase
setupLuksEncryption() {
  read -ep "Enter the path to your LUKS key file [/tmp/secret.key]: " keyFile
  keyFile=${keyFile:-/tmp/secret.key}

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
  luksPartition=$(blkid -t TYPE=crypto_LUKS -o device | grep "^${deviceDisk}[0-9]")

  if [[ -z "$luksPartition" ]]; then
    warn "No LUKS partition found on $deviceDisk"
    return 1
  fi

  info "Adding passphrase as a second LUKS key slot on $luksPartition"
  echo "You will be prompted to enter the new passphrase (twice for confirmation)."
  echo "The key file '$keyFile' will be used to authenticate this operation."

  run_command cryptsetup luksAddKey --key-file "$keyFile" --key-size "$keySize" "$luksPartition"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Passphrase successfully added to LUKS slot.${RESET}"
  else
    warn "Failed to add passphrase. You can retry manually with:"
    echo "  cryptsetup luksAddKey --key-file $keyFile $luksPartition"
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

  ### Partitionning the disk with disko
  # Get info if the host is UEFI or BIOS (boot method)
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

  echo "Available disks:"
  lsblk -d -n -o NAME,SIZE,TYPE | grep disk | grep -E '^(sd|vd|nvme|hd)'

  echo ""
  read -ep "Enter size of your new installation: " sizeDisk
  read -ep "Enter device to install NixOS (like /dev/sda, /dev/vda...): " deviceDisk
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

  if [[ "$diskoEncrypted" =~ ^[yY]$ ]] && [[ "$addPassphrase" =~ ^[yY]$ ]]; then
    addLuksPassphrase "$deviceDisk" "$keyFile" "$luksKeySize"
  fi

  sleep 1
  echo ""
  info "installing NixOS configuration with this profile: '$nixosProfile'"
  run_command nixos-install --no-channel-copy --flake .#$nixosProfile
}
