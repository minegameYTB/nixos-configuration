{
  lib,
  pkgsFor,
  inputs,
  specialArgs,
  defaultArch ? "x86_64-linux",
  ...
}:

let
  isoArch = defaultArch;
  pkgs = pkgsFor isoArch;
in
{
  isoArch = isoArch;

  isoSpecialArgs = system: (specialArgs system) // {
    users = [ "nixos" ];
    description = "NixOS Live User";
  };

  isoModule = "${inputs.nixpkgs-main}/nixos/modules/installer/cd-dvd/installation-cd-base.nix";

  ### 10 keyboard layouts (shared between iso-profile and iso-minimal-profile)
  layouts = [
    { layout = "us"; keymap = "us"; locale = "en_US.UTF-8"; label = "US English"; }
    { layout = "de"; keymap = "de"; locale = "de_DE.UTF-8"; label = "German"; }
    { layout = "es"; keymap = "es"; locale = "es_ES.UTF-8"; label = "Spanish"; }
    { layout = "it"; keymap = "it"; locale = "it_IT.UTF-8"; label = "Italian"; }
    { layout = "pt"; keymap = "pt"; locale = "pt_PT.UTF-8"; label = "Portuguese"; }
    { layout = "gb"; keymap = "gb"; locale = "en_GB.UTF-8"; label = "British English"; }
    { layout = "be"; keymap = "be"; locale = "fr_BE.UTF-8"; label = "Belgian"; }
    { layout = "ch"; keymap = "ch"; locale = "de_CH.UTF-8"; label = "Swiss"; }
    { layout = "ca"; keymap = "ca"; locale = "en_CA.UTF-8"; label = "Canadian"; }
    { layout = "fr"; keymap = "fr"; locale = "fr_FR.UTF-8"; label = "French (default)"; }
  ];

  ### Keyboard specialisation helper — one spec per layout
  mkKeyboardSpec = { layout, keymap, locale, label }: {
    specialisation."keyboard-${layout}" = {
      configuration = {
        isoImage.appendToMenuLabel = lib.mkForce " - ${label}";
        boot.kernelParams = [
          "kbd.layout=${layout}"
          "kbd.keymap=${keymap}"
          "kbd.locale=${locale}"
        ];
      };
    };
  };

  ### Welcome message — shared by both ISO profiles
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

  ### System service script — runs before display-manager
  keyboardSetupScript = pkgs.writeShellApplication {
    name = "keyboard-setup";
    runtimeInputs = with pkgs; [ coreutils gnused gawk kbd dconf ];
    text = ''
      CMDLINE=$(cat /proc/cmdline)

      get_param() {
        echo "$CMDLINE" | sed -n "s/.*$1=\([^ ]*\).*/\1/p"
      }

      KBD_LAYOUT=$(get_param kbd.layout)
      KBD_KEYMAP=$(get_param kbd.keymap)
      KBD_LOCALE=$(get_param kbd.locale)

      # French default when no kbd.* params
      if [ -z "$KBD_LAYOUT" ]; then
        KBD_LAYOUT="fr"
        KBD_KEYMAP="fr"
        KBD_LOCALE="fr_FR.UTF-8"
      fi

      # 1. Console
      if [ -n "$KBD_KEYMAP" ]; then
        loadkeys "$KBD_KEYMAP" 2>/dev/null || true
      fi

      # 2. Locale
      if [ -n "$KBD_LOCALE" ]; then
        export LANG="$KBD_LOCALE"
      fi

      # 3. X11
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

      # 4. GDM dconf
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

  ### User session script — re-applies layout after GNOME session init
  keyboardSessionScript = pkgs.writeShellApplication {
    name = "keyboard-session-apply";
    runtimeInputs = with pkgs; [ coreutils gnused glib dconf ];
    text = ''
      CMDLINE=$(cat /proc/cmdline)
      KBD_LAYOUT=$(echo "$CMDLINE" | sed -n 's/.*kbd\.layout=\([^ ]*\).*/\1/p')

      if [ -z "$KBD_LAYOUT" ]; then
        KBD_LAYOUT="fr"
      fi

      TARGET="[('xkb', '$KBD_LAYOUT')]"

      # Toggle via dummy to force GNOME to apply the change
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
}
