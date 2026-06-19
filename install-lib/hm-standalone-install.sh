### hm-standalone-install.sh — Home Manager standalone install on non-NixOS systems
### Sourced by install.sh; requires lib.sh to be sourced first.
# shellcheck shell=bash

hmInstallFn() {

  # --- Resume prompt -------------------------------------------------------
  checkpoint_resume_prompt

  # Restore persisted variables when resuming a previous session.
  if [[ "${RESUMING:-0}" == "1" ]]; then
    nixpkgs_ref="$(checkpoint_get "VAR_NIXPKGS_REF")"
    version="$(checkpoint_get     "VAR_VERSION")"
    hm_branch="$(checkpoint_get   "VAR_HM_BRANCH")"
    distro="$(checkpoint_get      "VAR_DISTRO")"
    nixArch="$(checkpoint_get     "VAR_ARCH")"
    userName="$(checkpoint_get    "VAR_USERNAME")"
  fi

  # --- Step: resolve nixpkgs ref and HM branch -----------------------------
  # Parse flake.lock once to decide which Home Manager branch to use.
  # This is fast and non-destructive, but we checkpoint it to persist the
  # results so resume does not need flake.lock to still be accessible.
  if ! checkpoint_skip "STEP_RESOLVE_BRANCH"; then
    nixpkgs_ref=$(jq -r \
      '.nodes."nixpkgs-main".original.ref // .nodes.nixpkgs.original.ref // empty' \
      flake.lock 2>/dev/null) || nixpkgs_ref=""

    version=$(echo "$nixpkgs_ref" | grep -oP '\d+\.\d+' || true)

    if [[ -n "$version" ]]; then
      hm_branch="home-manager/release-${version}"
      echo "Using nixpkgs stable ${version} from flake.lock (nixpkgs-main)"
    elif [[ "$nixpkgs_ref" == *"unstable"* ]]; then
      hm_branch="home-manager/master"
      info "nixpkgs-main is on unstable channel — using ${hm_branch}"
    else
      hm_branch="home-manager/master"
      warn "Could not parse flake.lock ref ('${nixpkgs_ref}') — falling back to ${hm_branch}"
    fi

    checkpoint_set "VAR_NIXPKGS_REF" "$nixpkgs_ref"
    checkpoint_set "VAR_VERSION"     "$version"
    checkpoint_set "VAR_HM_BRANCH"   "$hm_branch"

    checkpoint_done "STEP_RESOLVE_BRANCH"
  fi

  # --- Step: detect distro -------------------------------------------------
  if ! checkpoint_skip "STEP_DETECT_DISTRO"; then
    if [[ -f /etc/os-release ]]; then
      # Source the file in a subshell to avoid polluting the environment with
      # every variable it defines; we only need ID and PRETTY_NAME.
      distro=$(. /etc/os-release && echo "${ID:-unknown}")
      local pretty_name
      pretty_name=$(. /etc/os-release && echo "${PRETTY_NAME:-unknown}")
      echo "Detected distribution: ${distro} (${pretty_name})"
    else
      distro="unknown"
    fi

    checkpoint_set "VAR_DISTRO" "$distro"
    checkpoint_done "STEP_DETECT_DISTRO"
  fi

  # --- Step: install curl if missing ---------------------------------------
  if ! checkpoint_skip "STEP_INSTALL_CURL"; then
    if ! command -v curl &> /dev/null; then
      echo "curl is not installed — installing…"
      case "$distro" in
        ubuntu|debian|linuxmint|pop)
          run_command sudo apt update
          run_command sudo apt upgrade
          run_command sudo apt install -y curl
          ;;
        fedora|almalinux)
          run_command sudo dnf upgrade
          run_command sudo dnf install -y curl
          ;;
        *)
          warn "Distribution '${distro}' not supported — please install curl manually (Error 1)"
          exit 1
          ;;
      esac
      echo "curl is now installed"
    else
      echo "curl is already installed"
    fi
    checkpoint_done "STEP_INSTALL_CURL"
  fi

  # --- Step: install Flatpak and add Flathub remote ------------------------
  # App management is handled by the HM module — this only sets up the
  # system-level layer (flatpak binary + flathub remote).
  if ! checkpoint_skip "STEP_FLATPAK"; then
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
          warn "Distribution '${distro}' not supported for Flatpak installation — skipping"
          ;;
      esac
    else
      echo "flatpak is already installed"
    fi

    if flatpak remotes --system 2>/dev/null | grep -q "^flathub"; then
      echo "Flathub remote already registered (system)"
    else
      run_command sudo flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    checkpoint_done "STEP_FLATPAK"
  fi

  # --- Step: install Nix via Determinate Systems installer -----------------
  if ! checkpoint_skip "STEP_INSTALL_NIX"; then
    info "Installing Nix via nix-installer (Determinate Systems)"
    printf '%b\n' "${BLUE}▶ Run command:${RESET}  ${YELLOW}curl -fsSL nix-installer.sh | sh -s -- install --prefer-upstream-nix${RESET}" >&2
    curl -fsSL \
      https://github.com/DeterminateSystems/nix-installer/releases/download/v3.15.2/nix-installer.sh \
      | sh -s -- install --prefer-upstream-nix

    # Source the Nix daemon profile so `nix` is available in this shell session
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      # shellcheck source=/dev/null
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    else
      warn "nix-daemon.sh not found — Nix installation may have failed (Error 3)"
      exit 3
    fi

    if ! command -v nix &> /dev/null; then
      warn "Nix binary not found after install — installation may have failed (Error 3)"
      exit 3
    fi

    checkpoint_done "STEP_INSTALL_NIX"
  else
    # Resume path: Nix is already installed but not yet sourced in this shell.
    # Source the daemon profile so subsequent nix/home-manager calls work.
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      # shellcheck source=/dev/null
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  fi

  # --- Step: detect system architecture ------------------------------------
  if ! checkpoint_skip "STEP_DETECT_ARCH"; then
    local arch
    arch=$(uname -m)
    case "$arch" in
      x86_64)  nixArch="x86_64-linux"  ;;
      aarch64) nixArch="aarch64-linux" ;;
      *)
        warn "Unsupported architecture: ${arch} (Error 4)"
        exit 4
        ;;
    esac
    checkpoint_set "VAR_ARCH" "$nixArch"
    checkpoint_done "STEP_DETECT_ARCH"
  fi

  # --- Step: initialise first Home Manager generation ----------------------
  if ! checkpoint_skip "STEP_HM_INIT"; then
    info "Initialising HM first generation"
    run_command nix "${nixFlags[@]}" run "$hm_branch" -- init --switch
    checkpoint_done "STEP_HM_INIT"
  fi

  # --- Step: resolve username (interactive) --------------------------------
  if ! checkpoint_skip "STEP_GET_USER"; then
    getDefaultUser 5
    checkpoint_set "VAR_USERNAME" "$userName"
    checkpoint_done "STEP_GET_USER"
  else
    # Restore from state if this step was already done
    userName="${userName:-$(checkpoint_get "VAR_USERNAME")}"
  fi

  # --- Step: switch to flake-based HM configuration -----------------------
  if ! checkpoint_skip "STEP_HM_SWITCH"; then
    info "Installing HM as ${userName} (${nixArch})"
    run_command home-manager -b bak --flake ".#${userName}@${nixArch}" switch
    checkpoint_done "STEP_HM_SWITCH"
  fi

  # --- All steps completed — clean up state --------------------------------
  checkpoint_clear
  echo ""
  info "HM is installed — restart to apply desktop icons and environment changes"
}
