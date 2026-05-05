### Install hm standalone if non NixOS system

hmInstallFn() {
  nixpkgs_ref=$(jq -r '.nodes."nixpkgs-main".original.ref // .nodes.nixpkgs.original.ref // empty' \
    flake.lock 2>/dev/null) || nixpkgs_ref=""

  version=$(echo "$nixpkgs_ref" | grep -oP '\d+\.\d+' || true)

  ### detect distro and install curl if needed
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    distro="${ID:-unknown}"
    echo "Detected distribution: $distro (${PRETTY_NAME:-unknown})"
  else
    distro="unknown"
  fi

  if ! command -v curl &> /dev/null; then
    echo "curl is not installed, installing..."

    case "$distro" in
      ubuntu|debian|linuxmint|pop)
        run_command sudo apt update
        run_command sudo apt upgrade
        run_command sudo apt install -y curl
      ;;
      fedora|almalinux)
        run_command sudo dnf upgrade # update and upgrade package in a row
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

  ### Install flatpak system-wide and add Flathub remote
  ### App management is handled by the HM module — this only sets up the system layer
  info "Installing Flatpak and adding Flathub (system-wide)"

  if ! command -v flatpak &> /dev/null; then
    case "$distro" in
      ubuntu|debian|linuxmint|pop)
        run_command sudo apt install -y flatpak
      ;;
      fedora|almalinux)
        run_command sudo dnf install -y flatpak
      ;;
      *)
        warn "distribution not supported for flatpak installation, skipping (you may install it manually)"
      ;;
    esac
  else
    echo "flatpak is already installed"
  fi

  ### Add Flathub remote at system level if not already present
  if flatpak remotes --system 2>/dev/null | grep -q "^flathub"; then
    echo "Flathub remote already registered (system)"
  else
    run_command sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi

  if [[ -n "$version" ]]; then
    hm_branch="home-manager/release-${version}"
    echo "Using nixpkgs stable $version from flake.lock (nixpkgs-main)"
  elif [[ "$nixpkgs_ref" == *"unstable"* ]]; then
    hm_branch="home-manager/master"
    info "nixpkgs-main is on unstable channel, using $hm_branch"
  else
    hm_branch="home-manager/master"
    warn "Could not parse flake.lock ref ('$nixpkgs_ref'), falling back to $hm_branch"
  fi

  ### Install nix via determinate-nix project (upstream nix)
  info "Install Nix via nix-installer (determinate-nix project)"
  printf "\n${BLUE}▶ Run command:${RESET}  ${YELLOW}curl -fsSL nix-installer.sh | sh -s -- install --prefer-upstream-nix${RESET}\n\n" >&2
  curl -fsSL https://github.com/DeterminateSystems/nix-installer/releases/download/v3.15.2/nix-installer.sh \
    | sh -s -- install --prefer-upstream-nix

  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  else
    warn "nix-daemon.sh not found — Nix installation may have failed (Error 3)"
    exit 3
  fi

  if ! command -v nix &> /dev/null; then
    warn "Nix installation seems to have failed, nix binary not found (Error 3)"
    exit 3
  fi

  info "Initialize HM first generation"
  run_command nix "${nixFlags[@]}" run $hm_branch -- init --switch

  echo "Install HM configuration"

  ### Detect system architecture
  arch=$(uname -m)
  case "$arch" in
    x86_64)   nixArch="x86_64-linux" ;;
    aarch64)  nixArch="aarch64-linux" ;;
    *)
      warn "Unsupported architecture: $arch (Error 4)"
      exit 4
    ;;
  esac

  ### Extract default username from flake.nix and prompt for confirmation
  getDefaultUser 5

  info "Install HM as $userName ($nixArch)"
  run_command home-manager -b bak --flake .#$userName@$nixArch switch

  echo ""
  info "HM is installed, restart to add desktop icons"
}
