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
  ];

  mkKeyboardSpec =
    {
      layout,
      keymap,
      locale,
      label,
    }:
    {
      configuration = {
        isoImage.appendToMenuLabel = lib.mkForce " - ${label}";
        boot.kernelParams = [
          "kbd.layout=${layout}"
          "kbd.keymap=${keymap}"
          "kbd.locale=${locale}"
        ];
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
      username ? "nixos",
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
        ../configurations/config-modules/nix-index-db
        ../configurations/config-modules/stylix
      ];

      specialisation = builtins.listToAttrs (
        map (s: {
          name = "keyboard-${s.layout}";
          value = {
            configuration = {
              isoImage.appendToMenuLabel = lib.mkForce " ${edition} (${branch}) - ${s.label}";
              boot.kernelParams = [
                "kbd.layout=${s.layout}"
                "kbd.keymap=${s.keymap}"
                "kbd.locale=${s.locale}"
              ];
              i18n.defaultLocale = lib.mkForce s.locale;
            };
          };
        }) layouts
      );

      image.baseName = lib.mkForce "nixos-${config.system.nixos.release}.${rev}${
        lib.optionalString (branch != null) "-${branch}"
      }-${edition}";
      image.fileName = "${config.image.baseName}.iso";
      isoImage.volumeID =
        lib.substring 0 32
          "nixos-${edition}-${
            lib.optionalString (branch != null) "${branch}-"
          }${config.system.nixos.release}";
      isoImage.appendToMenuLabel = lib.mkDefault " ${edition} (${branch}) - AZERTY (Français)";
      isoImage.squashfsCompression = "zstd -Xcompression-level 13";

      i18n.defaultLocale = "fr_FR.UTF-8";
      boot.initrd.systemd.emergencyAccess = lib.mkForce true;
      boot.zfs = {
        forceImportRoot = false;
        package = config.boot.kernelPackages.zfs_cachyos;
      };

      ### Create new machine-id
      environment.etc."machine-id" = lib.mkForce {
        text = "43b1da0f0a6e4828a5ce286e398402d2";
        mode = "0444";
      };

      ### Disable nixos-rebuild tool
      system.tools.nixos-rebuild.enable = false;

      ### Change zfs hostID for iso
      networking.hostId = "43b1da0f";

      ### Force installing nixos tool (nixos-install)
      system.tools.nixos-install.enable = lib.mkForce true;

      users.users.${username} = {
        initialPassword = lib.mkForce "";
        initialHashedPassword = lib.mkForce null;
      };

      systemd.sleep.settings.Sleep = {
        AllowSuspend = "no";
        AllowHibernation = "no";
        AllowHybridSleep = "no";
        AllowSuspendThenHibernate = "no";
      };

      ### NetworkManager is enabled by configurations/configs/networking
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

      ### Only rsync, no vim (neovim is already provided via home-manager)
      environment.defaultPackages = lib.mkForce (with pkgs; [ rsync ]);

      environment.interactiveShellInit = welcomeMessage;
    };

  ### ISO nixosSystem builder — facto of the boilerplate shared by all variants
  mkIso =
    {
      edition,
      profile,
      hostname,
      hmFeatures ? [ ],
      keyboardSession ? false,
      extraModules ? [ ],
      extraHomeModules ? [ ],
      username ? "nixos",
      withHomeManager ? true,
    }:
    let
      isoUserCfg = {
        ${username} = {
          description = "NixOS Live User";
          inherit username hmFeatures;
        };
      };

      iSpecialArgs = isoSpecialArgs isoArch // {
        inherit
          mkKeyboardSpec
          keyboardSetupScript
          layouts
          mkIsoConfig
          username
          ;
        keyboardSessionScript = if keyboardSession then keyboardSessionScript else null;
        inherit rev branch;
        edition = edition;
        welcomeMessage = mkWelcomeMessage edition rev branch username;
        userConfigs = isoUserCfg;
        globalFeatures = [ ];
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
      ]
      ++ lib.optionals withHomeManager [
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = {
              imports = [
                (import ../hm-profiles/users/entry.nix {
                  inherit username;
                  globalFeatures = [ ];
                  userConfigs = isoUserCfg;
                  featPath = ../home-manager/features;
                  inherit inputs;
                })
              ]
              ++ extraHomeModules;
            };
            extraSpecialArgs = iSpecialArgs;
          };
        }
      ]
      ++ [ isoModule ]
      ++ extraModules;
    };

  isoSpecialArgs =
    system:
    (specialArgs system)
    // {
      userConfigs = {
        nixos = {
          description = "NixOS Live User";
          username = "nixos";
        };
      };
      globalFeatures = [ ];
    };

  isoModule = "${inputs.nixpkgs-main}/nixos/modules/installer/cd-dvd/installation-cd-base.nix";

  mkWelcomeMessage =
    edition: rev: branch: username:
    let
      versionStr = "${lib.trivial.release}.${rev}" + lib.optionalString (branch != null) ".${branch}";
    in
    ''
      if [ -z "$_NIXOS_ISO_WELCOME" ]; then
        _NIXOS_ISO_WELCOME=1

        _w=72
        _repeat() { local c="$1" n="$2"; for ((;n>0;n--)); do printf "%s" "$c"; done; }
        _line() { printf "│  %s" "$1"; _repeat " " $(( _w - 4 - ''${#1} )); printf "│\n"; }

        _p="┌─ NixOS Live — ${edition} "; printf "%s" "$_p"
        _repeat "─" $(( _w - ''${#_p} - 1 )); printf "┐\n"

        _line "${versionStr}"
        _line "install: nixos-config-install"
        _line "keymap:  FR (AZERTY) default / US (QWERTY) via"
        _line "         GRUB menu"
        _line "user:    ${username} (no password)"

        printf "└"; _repeat "─" $(( _w - 2 )); printf "┘\n"
        echo ""
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
