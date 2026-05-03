{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Nix Settings
  nix = {
    ### Use nix from ctrl os
    #package = pkgs.pkgs-lts.nix;

    ### Directory relative to channel are removed with the service "nix-channel-rm-dirs.service"
    channel.enable = false;
    #registry.nix-custom-repo.to =
    #  owner = "minegameYTB";
    #  repo = "nix-custom-repo";
    #  type = "github";
    #};
    settings = {
      warn-dirty = false;
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
      download-buffer-size = 134217728; # 128M for download buffer
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 2;
      cores = 2;
      #substituters = [
      #  "https://minegameytb.cachix.org"
      #];
      #trusted-public-keys = [
      #  "minegameytb.cachix.org-1:JvOgXYklqCayYEJWzlt0Sqc6zvs0S65ZZsWHYWh7qnc="
      #];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      randomizedDelaySec = "45min";
      options = "--delete-older-than 14d --max-freed 15G";
    };
    optimise = {
      automatic = true;
      dates = [ "monthly" ];
    };
  };

  ### Ctrl-os substitutes (custom option (defined in /configurations/modules/nix/ctrl-os-substitutes.nix))
  #ctrl-os.substitutes.enable = true;

  system = {
    ### Disable some nixos other command
    tools = {
      nixos-option.enable = false;
      nixos-build-vms.enable = false;
      nixos-install.enable = false;
    };
  };

  ### Override nixos-rebuild to use -F flag by default
  nixpkgs.overlays = [
    (self: super: {
      nixos-rebuild-ng = super.nixos-rebuild-ng.overrideAttrs (
        oldAttrs:
        let
          flakeWrapper = super.writeShellScript "nixos-rebuild-flake-wrapper" ''
            set -euo pipefail

            REAL_NRB="$(dirname "$(realpath "$0")")/.nixos-rebuild-wrapped"
            DEFAULT_FLAKE="''${NRB_FLAKE:-}"

            # --- colors ---
            if [[ -n "''${NO_COLOR:-}" ]] || [[ "''${TERM:-dumb}" == "dumb" ]] || ! [[ -t 1 ]]; then
                BOLD="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" RESET=""
            else
                BOLD='\033[1m'
                RED='\033[0;31m'
                GREEN='\033[0;32m'
                YELLOW='\033[0;33m'
                BLUE='\033[1;34m'
                MAGENTA='\033[1;35m'
                CYAN='\033[1;36m'
                RESET='\033[0m'
            fi

            warn() { printf "''${MAGENTA}warning:''${RESET} %s\n" "$*" >&2; }
            info()  { printf "''${CYAN}info:''${RESET} %s\n" "$*"; }

            BUILD_ACTIONS=( switch boot test build dry-build dry-activate build-vm build-vm-with-bootloader build-image repl edit )
            is_build_action() {
              local a="$1"; for x in "''${BUILD_ACTIONS[@]}"; do [[ "$x" == "$a" ]] && return 0; done; return 1;
            }
            has_flake_flag() {
              for a in "$@"; do [[ "$a" == "-F" || "$a" == "--flake" ]] && return 0; done; return 1;
            }
            looks_like_flake() {
              case "$1" in *\#*|./*|../*|/*) return 0;; *) return 1;; esac;
            }

            declare -A PERSONAL_CMDS
            register_cmd() { PERSONAL_CMDS["$1"]="$2"; }
            show_personal_help() {
              printf "''${BOLD}Personal commands:''${RESET}\n"
              for cmd in "''${!PERSONAL_CMDS[@]}"; do
                printf "  ''${GREEN}%-10s''${RESET} %s\n" "$cmd" "''${PERSONAL_CMDS[$cmd]}"
              done
              echo
              printf "''${YELLOW}Tip:''${RESET} run 'nixos-rebuild --help' for upstream help\n"
            }

            register_cmd "cmds"   "show this help for custom commands"
            register_cmd "status" "show host, flake path, and last 5 generations"
            register_cmd "hello"  "says hi !"

            case "''${1:-}" in
              cmds|personal)
                show_personal_help
                exit 0
                ;;
              status)
                info "host: $(hostname)"
                info "flake: ''${DEFAULT_FLAKE:-$(pwd)}"
                "$REAL_NRB" list-generations | tail -5
                exit 0
                ;;
              hello)
                echo "Hi !"
                exit 0
                ;;
            esac

            # fix argument order: ".#host switch" -> "switch .#host"
            if (( $# >= 2 )) && looks_like_flake "$1" && is_build_action "$2"; then
              set -- "$2" "$1" "''${@:3}"
            fi

            # auto-inject --flake
            if is_build_action "''${1:-}" && ! has_flake_flag "$@"; then
              if (( $# >= 2 )) && looks_like_flake "$2"; then
                info "injecting --flake $2"
                set -- "$1" --flake "$2" "''${@:3}"
              else
                info "injecting --flake"
                set -- "$1" --flake "''${@:2}"
              fi
            fi

            # ← point clé : exec remplace le process,
            #   ce qui permet à nixos-rebuild de se self-restart correctement
            exec "$REAL_NRB" "$@"
          '';
        in
        {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ super.makeWrapper ];

          postFixup = (oldAttrs.postFixup or "") + ''
            mv $out/bin/nixos-rebuild $out/bin/.nixos-rebuild-wrapped

            # Pas de --set REAL_NRB : on le résout au runtime via $0
            makeWrapper ${flakeWrapper} $out/bin/nixos-rebuild
          '';
        }
      );
    })
  ];
}
