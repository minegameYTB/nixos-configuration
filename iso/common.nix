{
  lib,
  pkgsFor,
  inputs,
  specialArgs,
  overlay,
  home-manager,
  rev,
  branch,
  defaultArch ? "x86_64-linux",
  ...
}:

let
  isoArch = defaultArch;
  pkgs = pkgsFor isoArch;

  layouts = [
    {
      layout = "us";
      keymap = "us";
      locale = "en_US.UTF-8";
      label = "US English";
    }
    {
      layout = "fr";
      keymap = "fr";
      locale = "fr_FR.UTF-8";
      label = "French (default)";
    }
  ];

  mkKeyboardSpec =
    edition: branch:
    {
      layout,
      keymap,
      locale,
      label,
    }:
    {
      specialisation."keyboard-${layout}" = {
        configuration = {
          isoImage.appendToMenuLabel = " ${edition} (${branch}) - ${label}";
          boot.kernelParams = [
            "kbd.layout=${layout}"
            "kbd.keymap=${keymap}"
            "kbd.locale=${locale}"
          ];
        };
      };
    };

  mkIsoConfig =
    {
      edition,
      rev,
      branch,
      welcomeMessage,
      keyboardSetupScript,
      keyboardSessionScript ? null,
    }:
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        ../configurations/configuration.nix
        ../configurations/configs/networking
        ../configurations/config-modules
        ../configurations/configs/system/tmp-on-tmpfs.nix

        ### NVIDIA configuration
        ../configurations/hardware-configuration/specific/nvidia.nix
      ]
      ++ map (mkKeyboardSpec edition branch) layouts;

      image.baseName = lib.mkForce "nixos-${config.system.nixos.release}.${lib.substring 0 7 rev}.${branch}-${edition}";
      image.fileName = "${config.image.baseName}.iso";
      isoImage.volumeID = "nixos-${edition}-${branch}-${config.system.nixos.release}";
      isoImage.appendToMenuLabel = lib.mkForce " ${edition} (${branch})";
      isoImage.squashfsCompression = "zstd";

      i18n.defaultLocale = "fr_FR.UTF-8";
      boot.initrd.systemd.emergencyAccess = lib.mkForce true;
      boot.zfs = {
        forceImportRoot = false;
        package = config.boot.kernelPackages.zfs_cachyos;
      };

      users.users.nixos.initialPassword = lib.mkForce "";
      users.users.nixos.initialHashedPassword = lib.mkForce null;

      systemd.sleep.settings.Sleep = {
        AllowSuspend = "no";
        AllowHibernation = "no";
        AllowHybridSleep = "no";
        AllowSuspendThenHibernate = "no";
      };

      networking.networkmanager.enable = true;
      services.openssh.enable = true;

      systemd.services.keyboard-setup = {
        description = "Apply keyboard layout from kernel cmdline";
        wantedBy = [ "multi-user.target" ];
        before = [ "display-manager.service" ];
        after = [
          "local-fs.target"
          "systemd-vconsole-setup.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe keyboardSetupScript}";
        };
      };

      environment.systemPackages = [
        pkgs.pkgsConfig.nixos-config
      ]
      ++ lib.optional (keyboardSessionScript != null) keyboardSessionScript;

      environment.interactiveShellInit = welcomeMessage;
    };

  ### ISO nixosSystem builder — facto of the boilerplate shared by all variants
  mkIso =
    {
      edition,
      profile,
      hostname,
      hmProfile,
      hmExtraModules ? [ ],
      keyboardSession ? false,
      extraModules ? [ ],
    }:
    let
      iSpecialArgs = isoSpecialArgs isoArch // {
        inherit
          mkKeyboardSpec
          keyboardSetupScript
          layouts
          mkIsoConfig
          ;
        keyboardSessionScript = if keyboardSession then keyboardSessionScript else null;
        inherit rev branch;
        edition = edition;
        welcomeMessage = mkWelcomeMessage edition;
      };
    in
    lib.nixosSystem {
      system = isoArch;
      pkgs = pkgsFor isoArch;
      specialArgs = iSpecialArgs;
      modules = [
        profile
        (overlay isoArch)
        { networking.hostName = hostname; }
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.nixos = import hmProfile {
              username = "nixos";
              extraModules = hmExtraModules;
            };
            extraSpecialArgs = iSpecialArgs;
          };
        }
        isoModule
      ]
      ++ extraModules;
    };

  isoSpecialArgs =
    system:
    (specialArgs system)
    // {
      users = [ "nixos" ];
      description = "NixOS Live User";
    };

  isoModule = "${inputs.nixpkgs-main}/nixos/modules/installer/cd-dvd/installation-cd-base.nix";

  mkWelcomeMessage = edition: ''
    if [ -z "$_NIXOS_ISO_WELCOME" ]; then
      _NIXOS_ISO_WELCOME=1
      cat <<'WELCOME'
    ╔══════════════════════════════════════════════╗
    ║      NixOS Live ISO — ${edition} Edition      ║
    ║                                              ║
    ║  Run the following command to install:        ║
    ║  nixos-config-install                        ║
    ║                                              ║
    ║  Keyboard: select at GRUB menu (e.g. us, de) ║
    ║  User: nixos (no password)                   ║
    ╚══════════════════════════════════════════════╝
    WELCOME
    fi
  '';

  keyboardSetupScript = pkgs.writeShellApplication {
    name = "keyboard-setup";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      gawk
      kbd
      dconf
    ];
    text = ''
      CMDLINE=$(cat /proc/cmdline)

      get_param() {
        echo "$CMDLINE" | sed -n "s/.*$1=\([^ ]*\).*/\1/p"
      }

      KBD_LAYOUT=$(get_param kbd.layout)
      KBD_KEYMAP=$(get_param kbd.keymap)
      KBD_LOCALE=$(get_param kbd.locale)

      if [ -z "$KBD_LAYOUT" ]; then
        KBD_LAYOUT="fr"
        KBD_KEYMAP="fr"
        KBD_LOCALE="fr_FR.UTF-8"
      fi

      if [ -n "$KBD_KEYMAP" ]; then
        loadkeys "$KBD_KEYMAP" 2>/dev/null || true
      fi

      if [ -n "$KBD_LOCALE" ]; then
        export LANG="$KBD_LOCALE"
      fi

      if mkdir -p /etc/X11/xorg.conf.d 2>/dev/null; then
        rm -f /etc/X11/xorg.conf.d/00-keyboard.conf
        cat > /etc/X11/xorg.conf.d/00-keyboard.conf << XEOF
      Section "InputClass"
          Identifier "keyboard-layout"
          MatchIsKeyboard "on"
          Option "XkbLayout" "$KBD_LAYOUT"
      EndSection
      XEOF
      fi

      {
        DCONF_KEYFILE=$(mktemp -d)/input-sources
        mkdir -p "$(dirname "$DCONF_KEYFILE")"
        cat > "$DCONF_KEYFILE" << DEOF
      [org/gnome/desktop/input-sources]
      sources=[('xkb', '$KBD_LAYOUT')]
      DEOF

        GDM_DCONF_DIR="/var/lib/gdm/.config/dconf"
        mkdir -p "$GDM_DCONF_DIR" 2>/dev/null || true
        if [ -d "$GDM_DCONF_DIR" ]; then
          dconf compile "$GDM_DCONF_DIR/user" "$(dirname "$DCONF_KEYFILE")" 2>/dev/null || true
          chown -R gdm:gdm "$GDM_DCONF_DIR" 2>/dev/null || true
        fi

        for userdir in /home/*; do
          if [ -d "$userdir" ]; then
            USER_DCONF_DIR="$userdir/.config/dconf"
            mkdir -p "$USER_DCONF_DIR" 2>/dev/null || true
            if [ -d "$USER_DCONF_DIR" ]; then
              dconf compile "$USER_DCONF_DIR/user" "$(dirname "$DCONF_KEYFILE")" 2>/dev/null || true
              USERNAME=$(basename "$userdir")
              chown "$USERNAME" "$userdir/.config" 2>/dev/null || true
              chown -R "$USERNAME" "$USER_DCONF_DIR" 2>/dev/null || true
            fi
          fi
        done

        rm -rf "$(dirname "$DCONF_KEYFILE")"
      }
    '';
  };

  keyboardSessionScript = pkgs.writeShellApplication {
    name = "keyboard-session-apply";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      glib
      dconf
    ];
    text = ''
      CMDLINE=$(cat /proc/cmdline)
      KBD_LAYOUT=$(echo "$CMDLINE" | sed -n 's/.*kbd\.layout=\([^ ]*\).*/\1/p')

      if [ -z "$KBD_LAYOUT" ]; then
        KBD_LAYOUT="fr"
      fi

      TARGET="[('xkb', '$KBD_LAYOUT')]"

      if [ "$KBD_LAYOUT" = "us" ]; then
        DUMMY="fr"
      else
        DUMMY="us"
      fi

      gsettings set org.gnome.desktop.input-sources sources "[('xkb', '$DUMMY')]"
      sleep 1
      gsettings set org.gnome.desktop.input-sources sources "$TARGET"
      sleep 1

      AFTER=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || echo "error")
      if echo "$AFTER" | grep -q "$KBD_LAYOUT"; then
        true
      else
        echo "keyboard-session-apply: WARNING value is $AFTER, expected $KBD_LAYOUT"
      fi
    '';
  };

in
{
  inherit
    isoArch
    isoSpecialArgs
    isoModule
    layouts
    mkKeyboardSpec
    mkIsoConfig
    mkIso
    mkWelcomeMessage
    keyboardSetupScript
    keyboardSessionScript
    ;
}
