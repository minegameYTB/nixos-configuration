#!/usr/bin/env bash

### Install hm standalone if non NixOS system

hmInstallFn() {
  nixpkgs_ref=$(jq -r '.nodes."nixpkgs-main".original.ref // .nodes.nixpkgs.original.ref' flake.lock 2>/dev/null)
  version=$(echo "$nixpkgs_ref" | grep -oP '\d+\.\d+')

  ### detect distro and install curl if needed
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    distro=$ID
    echo "Detected distribution: $distro ($PRETTY_NAME)"
  fi

  if ! command -v curl &> /dev/null; then
    echo "curl is not installed, installing..."

    case "$distro" in
      ubuntu|debian|linuxmint|pop)
        run_command sudo apt update
        run_command sudo apt install -y curl
      ;;
      fedora|almalinux)
        run_command sudo dnf install -y curl
      ;;
      *) 
        warn "distribution not supported, please install curl manually with your package manager (Stopped at curl installation (Error 1)"
        exit 1
      ;;
    esac

    echo "curl is now installed"
  else
     echo "curl is already installed"
  fi


  if [[ -n "$version" ]]; then
    hm_branch="home-manager/release-${version}"
    echo "Using nixpkgs $version from flake.lock (nixpkgs-main)"
  else
    hm_branch="home-manager/master"
    warn "Could not parse flake.lock, using default $hm_branch"
  fi

  ### Install nix via determinate-nix project (upstream nix)
  echo "Install Nix via nix-installer (determinate-nix project)"
  run_command curl -fsSL https://github.com/DeterminateSystems/nix-installer/releases/download/v3.15.2/nix-installer.sh | sh -s -- install --prefer-upstream-nix
  ### Test if nix is installed correctly (source is configuration btw)
  if command -v nix &> /dev/zero; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  echo "Initialize HM first generation"
  run_command nix "${nixFlags[@]}" $hm_branch -- init --switch

  echo "Install HM configuration"

  read -ep "What is your username ? (the username need to be change in flake.nix, users.nix...) " userName
  echo "Install HM as $userName (x86_64-linux is hardcoded)"
  home-manager -b bak --flake .#$userName@x86_64-linux switch
}
