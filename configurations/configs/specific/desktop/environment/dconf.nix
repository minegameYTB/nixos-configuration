{
  lib,
  config,
  pkgs,
  ...
}:

let
  gv = lib.gvariant;

  ### blur-my-shell effect pipelines.
  ###
  ### The `pipelines` key (type a{sa{sv}}) holds every pipeline definition.
  ### dconf knows nothing about sub-keys: writing this key *replaces* the
  ### schema default wholesale, so all five pipelines shipped by the schema
  ### must be spelled out here — omitting `pipeline_default` would break the
  ### panel/applications/overview components, which reference it by name.
  ###
  ### The definitions below are the v77 schema default verbatim, except for
  ### `pipeline_liquid_glass`, whose luminosity effect carries the tweaks made
  ### in the preferences (that pipeline is what `popup.pipeline` selects).
  ### Params left out of an effect fall back to the effect class defaults
  ### (see `effects_manager.js`), so only the changed ones need to be listed —
  ### `saturation_multiplicator` is kept explicit because the schema default
  ### (1.1) differs from the class default (1.0).

  # a{sv} — dict whose values are GVariant variants: pipelines, effects, params
  svDict =
    attrs: gv.mkArray (lib.mapAttrsToList (k: v: gv.mkDictionaryEntry k (gv.mkVariant v)) attrs);

  # a{sT} — dict keeping each value's own type: the top-level a{sa{sv}} map,
  # whose values are a{sv} and must NOT be wrapped in a variant again.
  sDict = attrs: gv.mkArray (lib.mapAttrsToList (k: v: gv.mkDictionaryEntry k v) attrs);

  # An effect entry: { type, id, params? } wrapped in a variant.
  effect =
    type: id: params:
    gv.mkVariant (
      svDict ({ inherit type id; } // lib.optionalAttrs (params != { }) { params = svDict params; })
    );

  pipelines = sDict {
    pipeline_default = svDict {
      name = "Default";
      effects = gv.mkArray [
        (effect "dual_kawase_blur" "effect_000000000000" {
          unscaled_radius = gv.mkInt32 30;
          brightness = 0.6;
        })
      ];
    };

    pipeline_liquid_glass = svDict {
      name = "Liquid Glass";
      effects = gv.mkArray [
        (effect "luminosity" "effect_liquid_glass_luminosity" {
          saturation_multiplicator = 1.1;
          # "Shift brightness" / "Brightness multiplier" — the two sliders
          # tuned in the pipeline editor (defaults: 0.0 / 1.0).
          brightness_shift = 0.0;
          brightness_multiplicator = 0.7;
        })
        (effect "refraction" "effect_liquid_glass_refraction" { tint = gv.mkInt32 0; })
        (effect "noise" "effect_liquid_glass_noise" { noise = 0.1; })
      ];
    };

    pipeline_vapor_glass = svDict {
      name = "Vapor Glass";
      effects = gv.mkArray [
        (effect "luminosity" "effect_vapor_glass_luminosity" {
          saturation_multiplicator = 1.1;
        })
        (effect "wave" "effect_vapor_glass_wave" { })
        (effect "refraction" "effect_vapor_glass_refraction" { tint = gv.mkInt32 0; })
        (effect "noise" "effect_vapor_glass_noise" { noise = 0.1; })
      ];
    };

    pipeline_classic_light_background = svDict {
      name = "Classic Light Background";
      effects = gv.mkArray [
        (effect "dual_kawase_blur" "effect_classic_light_blur" {
          unscaled_radius = gv.mkInt32 30;
          brightness = 0.6;
        })
        (effect "color" "effect_classic_light_color" {
          color = gv.mkTuple [
            1.0
            1.0
            1.0
            0.25
          ];
          blend_mode = gv.mkInt32 17;
        })
      ];
    };

    pipeline_classic_dark_background = svDict {
      name = "Classic Dark Background";
      effects = gv.mkArray [
        (effect "dual_kawase_blur" "effect_classic_dark_blur" {
          unscaled_radius = gv.mkInt32 30;
          brightness = 0.6;
        })
        (effect "color" "effect_classic_dark_color" {
          color = gv.mkTuple [
            0.4
            0.4
            0.4
            0.35
          ];
          blend_mode = gv.mkInt32 17;
        })
      ];
    };
  };
in
{
  ### Dconf settings
  programs.dconf = {
    enable = true;
    profiles = {
      gdm.databases = [
        {
          settings = {
            "org/gnome/desktop/peripherals/keyboard" = {
              numlock-state = true;
            };
          };
        }
      ];
      user.databases = [
        {
          ### Lock some settings
          locks = [
            "/org/gnome/desktop/app-folders/folder-children"
          ];
          settings = {
            "org/gnome/desktop/wm/preferences" = {
              button-layout = ":minimize,maximize,close";
            };

            "org/gnome/mutter" = {
              attach-modal-dialogs = true;
              center-new-windows = true;
              dynamic-workspaces = true;
              edge-tiling = true;
              check-alive-timeout = lib.gvariant.mkUint32 60000; # Timeout of 60s bfor show quit app pop-up
            };

            "org/gnome/desktop/interface" = {
              clock-show-weekday = true;
              clock-show-date = true;
              color-scheme = "prefer-dark";
              gtk-theme = "adw-gtk3-dark";
              icon-theme = "Papirus-Dark";
              show-battery-percentage = true;
            };

            "org/gnome/shell/app-switcher" = {
              current-workspace-only = true;
            };

            "org/gnome/shell/extensions/blur-my-shell" = {
              inherit pipelines;
            };

            "org/gnome/shell/extensions/blur-my-shell/panel" = {
              static-blur = false;
              gradient-panel = true;
              # 0 = Top, 1 = Bottom
              gradient-panel-mode = lib.gvariant.mkInt32 0;
              override-background-dynamically = true;
              # 0 = Blur on Window Proximity, 1 = Background on Window Proximity
              override-background-dynamically-mode = lib.gvariant.mkInt32 0;
            };

            "org/gnome/shell/extensions/blur-my-shell/applications" = {
              blur = true;
              brightness = "0.8";
              opacity = lib.gvariant.mkInt32 245;
              dynamic-opacity = false;
              # "Blur on overview" — shows the blur on every workspace, at some
              # performance cost (default false)
              blur-on-overview = true;
              whitelist = [ "com.mitchellh.ghostty" ];
            };

            "org/gnome/shell/extensions/blur-my-shell/popup" = {
              pipeline = "pipeline_liquid_glass";
            };

            "org/gnome/shell/extensions/dash-to-dock" = {
              dock-position = "LEFT";
              transparency-mode = "DYNAMIC";
              running-indicator-style = "DOTS";
              running-indicator-dominant-color = true;
              custom-background-color = true;
              background-color = "rgb(36,31,49)";
              dash-max-icon-size = lib.gvariant.mkInt32 26;
              multi-monitor = true;
              custom-theme-shrink = true;
              click-action = "minimize-or-previews";
              intellihide-mode = "ALL_WINDOWS";
            };

            "org/gnome/shell/extensions/Logo-menu" = {
              hide-forcequit = true;
              hide-softwarecentre = true;
              menu-button-icon-image = lib.gvariant.mkInt32 23;
              menu-button-terminal = "ghostty";
              menu-button-extensions-app = "com.mattjakeman.ExtensionManager.desktop";
              menu-button-system-monitor = "missioncenter";
              symbolic-icon = true;
            };

            "org/gnome/shell/extensions/tiling-assistant" = {
              enable-layout-picker = false;
            };

            "org/gnome/shell/extensions/user-theme" = {
              name = "Marble-red-dark-filled";
            };

            "org/gnome/shell/extensions/clipboard-history" = {
              cache-only-favorites = true;
              window-width-percentage = lib.gvariant.mkInt32 28;
            };

            "org/gnome/shell" = {
              enabled-extensions = with pkgs.gnomeExtensions; [
                appindicator.extensionUuid
                blur-my-shell.extensionUuid
                dash-to-dock.extensionUuid
                hide-activities-button.extensionUuid
                logo-menu.extensionUuid
                user-themes.extensionUuid
                tiling-assistant.extensionUuid
                clipboard-history.extensionUuid
                no-overview.extensionUuid
                quick-settings-audio-panel.extensionUuid
                grand-theft-focus.extensionUuid
                caffeine.extensionUuid
                bluetooth-battery-meter.extensionUuid
                gsconnect.extensionUuid
              ];
              favorite-apps = [
                "zen-beta.desktop"
                "org.gnome.Calendar.desktop"
                "org.gnome.Nautilus.desktop"
                "com.mitchellh.ghostty.desktop"
                "virt-manager.desktop"
                "discord.desktop"
                "deezer-enhanced.desktop"
              ];
            };

            ### Custom keybinds
            "org/gnome/settings-daemon/plugins/media-keys" = {
              custom-keybindings = [
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
              ];
            };

            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
              binding = "<Control><Alt>t";
              command = "ghostty";
              name = "Terminal";
            };

            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
              binding = "<Shift><Control>Escape";
              command = "missioncenter";
              name = "Task Manager";
            };

            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
              binding = "<Super>e";
              command = "nautilus -w";
              name = "File Manager";
            };

            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
              binding = "<Super>i";
              command = "gnome-control-center";
              name = "Settings";
            };

            ### App Folders configuration
            "org/gnome/desktop/app-folders" = {
              folder-children = [
                "accessories"
                "chrome-apps"
                "games"
                "graphics"
                "internet"
                "office"
                "programming"
                "science"
                "sound---video"
                "system-tools"
                "universal-access"
                "wine"
                "waydroid"
                "education"
              ];
            };

            "org/gnome/desktop/app-folders/folders/accessories" = {
              name = "Accessories";
              categories = [ "Utility" ];
            };

            "org/gnome/desktop/app-folders/folders/chrome-apps" = {
              name = "Chrome Apps";
              categories = [ "chrome-apps" ];
            };

            "org/gnome/desktop/app-folders/folders/games" = {
              name = "Games";
              categories = [ "Game" ];
            };

            "org/gnome/desktop/app-folders/folders/graphics" = {
              name = "Graphics";
              categories = [ "Graphics" ];
            };

            "org/gnome/desktop/app-folders/folders/internet" = {
              name = "Internet";
              categories = [
                "Network"
                "WebBrowser"
                "Email"
              ];
            };

            "org/gnome/desktop/app-folders/folders/office" = {
              name = "Office";
              categories = [ "Office" ];
            };

            "org/gnome/desktop/app-folders/folders/programming" = {
              name = "Programming";
              categories = [ "Development" ];
            };

            "org/gnome/desktop/app-folders/folders/science" = {
              name = "Science";
              categories = [ "Science" ];
            };

            "org/gnome/desktop/app-folders/folders/sound---video" = {
              name = "Sound & Video";
              categories = [
                "AudioVideo"
                "Audio"
                "Video"
              ];
            };

            "org/gnome/desktop/app-folders/folders/system-tools" = {
              name = "System Tools";
              categories = [
                "System"
                "Settings"
              ];
            };

            "org/gnome/desktop/app-folders/folders/universal-access" = {
              name = "Universal Access";
              categories = [ "Accessibility" ];
            };

            "org/gnome/desktop/app-folders/folders/wine" = {
              name = "Wine";
              categories = [
                "Wine"
                "X-Wine"
                "Wine-Programs-Accessories"
              ];
            };

            "org/gnome/desktop/app-folders/folders/waydroid" = {
              name = "Waydroid";
              categories = [ "X-WayDroid-App" ];
            };

            "org/gnome/desktop/app-folders/folders/education" = {
              name = "Languages & Education";
              categories = [
                "Languages"
                "Education"
              ];
            };

            "org/gnome/nautilus/preferences" = {
              show-create-link = true;
              show-delete-permanently = true;
            };

            "org/gnome/TextEditor" = {
              restore-session = false;
              custom-font = "Adwaita Mono 10";
              use-system-font = false;
              spellcheck = false;
              show-line-numbers = true;
              #style-scheme = if config.stylix.enable then "stylix" else "Adwaita-dark";
            };

            "org/gnome/desktop/privacy" = {
              old-files-age = lib.gvariant.mkInt32 7;
              recent-files-max-age = lib.gvariant.mkInt32 7;
              remove-old-temp-files = true;
              remove-old-trash-files = true;
            };
            ### Other gsettings settings here
          };
        }
      ];
    };
  };
}
