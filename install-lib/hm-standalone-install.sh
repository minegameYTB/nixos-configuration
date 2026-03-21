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
  echo "Install Nix via nix-installer (determinate-nix project)"
  printf "\n${BLUE}▶ Run command:${RESET}  ${YELLOW}curl -fsSL nix-installer.sh | sh -s -- install --prefer-upstream-nix${RESET}\n\n" >&2
  curl -fsSL https://github.com/DeterminateSystems/nix-installer/releases/download/v3.15.2/nix-installer.sh \
    | sh -s -- install --prefer-upstream-nix

  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  if ! command -v nix &> /dev/null; then
    warn "Nix installation seems to have failed, nix binary not found (Error 3)"
    exit 3
  fi

  echo "Initialize HM first generation"
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

  ### Extract default username from flake.nix (users = [ "..." ])
  default_user=$(grep -oP '(?<=users = \[ ")[^"]+' flake.nix 2>/dev/null | head -1)

  read -r -p "What is your username ? [${default_user}] " userName
  userName="${userName:-$default_user}"

  if [[ -z "$userName" ]]; then
    warn "No username provided and could not parse flake.nix (Error 5)"
    exit 5
  fi

  echo "Install HM as $userName ($nixArch)"
  run_command home-manager -b bak --flake .#$userName@$nixArch switch
}
