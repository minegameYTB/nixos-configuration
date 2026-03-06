#!/usr/bin/env bash

### Install script for NixOS systems

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
  
  echo -e "\033[1;33m/!\ Starting installation in:\033[0m"
    for i in {5..1}; do
    echo -ne "\r  ${CYAN}$i${RESET} seconds... (Ctrl+C to cancel) "
    sleep 1
  done
  echo -e "\r  ${GREEN} - Installing NixOS conf${RESET}                    \n"
  
  info "Partitionning disk"
  diskoArgs=(--argstr device "$deviceDisk" --argstr size "$sizeDisk") # Dynamic args for disko

  if [[ "$diskoEncrypted" =~ ^[yY]$ ]]; then
    read -p "Enter the path to your LUKS key file [/tmp/secret.key]: " keyFile
    keyFile=${keyFile:-/tmp/secret.key} # Same method here
    diskoArgs+=(--argstr keyFile $keyFile)
  fi

  run_command nix "${nixFlags[@]}" run \
    nixpkgs/$nixpkgsRev#disko -- -m destroy,format,mount $diskoFile \
    "${diskoArgs[@]}"

  sleep 1
  echo ""
  info "installing NixOS configuration with this profile: '$nixosProfile'"
  run_command nixos-install --no-channel-copy --flake .#$nixosProfile
}
