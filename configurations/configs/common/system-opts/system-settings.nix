{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Nvd diff hook
  system.activationScripts.report-changes =
    let
      binPath = lib.makeBinPath (
        with pkgs;
        [
          nvd
          coreutils
          gawk
        ]
        ++ [ config.nix.package ]
      );
    in
    {
      supportsDryActivation = true;
      text = ''
        report-changes() {
          local PATH="${binPath}:$PATH"
          currentProfile=/nix/var/nix/profiles/system
          newSystem="$1"

          # dry-activate: $1 is empty, exit cleanly
          if [ -z "$newSystem" ]; then
            return 0
          fi

          # initrd: /etc/initrd-release is only present in the initrd environment
          if [ -e /etc/initrd-release ] || [ "''${SYSTEMD_IN_INITRD:-}" = "1" ]; then
            echo "=== initrd detected: skipping nvd diff ==="
            return 0
          fi

          # nixos-install: system profile does not exist yet
          if [ ! -L "$currentProfile" ]; then
            echo "=== first activation / nixos-install: skipping nvd diff ==="
            return 0
          fi

          # Resolve the previous generation store path
          # (NixOS updates the symlink before running activation scripts)
          oldGeneration=$(nix-env --list-generations -p "$currentProfile" 2>/dev/null \
            | awk '/\(current\)/{print prev} {prev=$1}')
          if [ -z "$oldGeneration" ]; then
            echo "=== no previous generation found: skipping nvd diff ==="
            return 0
          fi
          oldSystem=$(readlink -f "${"\${currentProfile}"}-''${oldGeneration}-link" 2>/dev/null)
          if [ -z "$oldSystem" ]; then
            echo "=== could not resolve previous generation: skipping nvd diff ==="
            return 0
          fi

          # Nothing changed, skip diff
          if [ "$oldSystem" = "$newSystem" ]; then
            return 0
          fi

          echo -e "\n===================================="
          echo    "| Running nvd diff to show changes |"
          echo -e "====================================\n"
          nvd diff "$oldSystem" "$newSystem" || true
          echo
        }

        report-changes "$1"
      '';
    };

  ### Ssh cli package (replace openssl by libressl)
  programs.ssh.package = pkgs.symlinkJoin {
    name = "openssh-libressl-${pkgs.openssh.version}";
    paths = [
      (pkgs.openssh.override {
        openssl = pkgs.libressl;
      })
    ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/ssh \
        --set TERM "xterm-256color" \
    '';
  };

  ### Zram
  zramSwap.enable = true;

  ### Fstrim
  services.fstrim.enable = if (config.fileSystems."/".fsType != "zfs") then true else false;

  ### Fwupd
  services.fwupd.enable = true;

  ### Nix-ld
  programs.nix-ld.enable = true;

  ### GVFS
  services.gvfs.enable = true;

  ### Udev
  services.udev.packages = [ pkgs.gnome-settings-daemon ];

  ### expose flake in top level derivation
  system.copyFlakeConfiguration = true;

  ### Appimage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
