#!/usr/bin/env bash

### Define restricted PATH for NixOS usage
PATH="/bin:/usr/bin:/run/current-system/sw/bin"

### Define installLib as a variable (make changes easy), main function will by present on the install script directly
installLib=$(pwd)/install-lib

### Source lib shell script (common and reusable function and variable)
source $installLib/lib.sh

### Source install method
source $installLib/nixos-install.sh
source $installLib/hm-standalone-install.sh

echo "$0 v1.0b"
sleep 2

### Check if host is nixos (check also root app directory (/run/current-system and not /bin or /sbin))
### Logic: if /etc/NIXOS and /run/current-system is present (or /run/booted-system), count as a nixos system

if [[ -e "/etc/NIXOS" && -d "/run/current-system" ]]; then
  info "NixOS based OS detected (by /etc/NIXOS and /run/current-system), continued install phase\n"
  mode=nixosInstall
else
  if [[ "$(uname -s)" != "Linux" ]]; then
    warn "This script is designed to be used on Linux systems (Sorry BSD, macOS and Solaris (and derivative) users)"
    echo "Stopped at install step (Error 2)"
    exit 2
  fi
  info "Non NixOS system detected, assuming you're on Linux system, continuing install script, but for HM standalone\n"
  mode=hmInstall
fi

case "$mode" in
  nixosInstall)
    nixosInstallFn
  ;;
  hmInstall)
    hmInstallFn
  ;;
esac
