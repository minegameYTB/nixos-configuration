# Home Manager — Architecture & User Guide

## Architecture

```
hm-profiles/
├── users.nix                     # Source of truth (users + features)
├── users/entry.nix                # Shared HM entry point
├── users/minegame/
│   ├── default.nix               # Calls entry.nix with username + overrides
│   ├── git.nix                    # User git config
│   └── apps.nix                   # Apps config (ghostty, fastfetch, ...)
├── users/matt/
│   ├── default.nix
│   ├── git.nix
│   └── apps.nix
└── users/nixos/
    └── default.nix                # ISO user (calls entry.nix, no override)

home-manager/
├── features/                      # Activation modules (HM only)
│   ├── cli.nix                    # Inline feature
│   ├── shell.nix                  # Inline feature
│   ├── desktop-core.nix           # Inline feature
│   ├── gnome.nix                  # Inline feature
│   ├── development.nix            # Wrapper → config-modules/lazyvim
│   ├── browser.nix                # Wrapper → config-modules/zen-browser
│   ├── games.nix                  # Inline feature
│   ├── multimedia.nix             # Inline feature
│   └── customization.nix          # Inline feature
├── config-modules/                # External modules (source of truth)
│   ├── default.nix                # Visual aggregator
│   ├── lazyvim/default.nix        # Flake import + lazyvim config
│   └── zen-browser/default.nix    # Flake import + zen-browser config
└── configs/specific/standalone/   # HM standalone-only configs
```

### Execution flow

```
flake.nix
  → homeManagerConfig
    → users = [ "minegame" "matt" ]
    → home-manager.users.${username} = import hm-profiles/users/${username}/default.nix
      → entry.nix
        → username = "minegame"
        → imports = features/${name}.nix for each (globalFeatures ++ cfg.hmFeatures)
          → features/development.nix → imports config-modules/lazyvim (via inputs.self)
          → features/gnome.nix → content inline
```

## Managing users

### Adding a user

1. **Declare in `hm-profiles/users.nix`**:
   ```nix
   users = {
     alice = {
       description = "Alice";
       hmFeatures = [ "cli" "shell" "gnome" "browser" ];
     };
   };
   ```

2. **Create the HM profile** — `hm-profiles/users/alice/default.nix`:
   ```nix
   { globalFeatures, userConfigs, ... }:

   let
     entry = import ../entry.nix {
       inherit globalFeatures userConfigs;
       username = "alice";                    # ⚠️ MUST match the key in users.nix
       featPath = ../../../home-manager/features;
     };
   in
   entry // {
     imports = entry.imports ++ [
       ./git.nix    # optional
       ./apps.nix   # optional
     ];
   }
   ```

3. **Optional** — Create `git.nix` and `apps.nix` in the same directory.

4. **`git add`** (mandatory for flakes) + build.

### Removing a user

1. Remove the entry from `hm-profiles/users.nix`
2. Delete `hm-profiles/users/<name>/`
3. `git add` + build

## Managing features

### Inline feature (simple)

Create `home-manager/features/<name>.nix` with the HM content directly:

```nix
{ pkgs, ... }: {
  home.packages = [ pkgs.hello ];
}
```

Add `"<name>"` to the user's `globalFeatures` or `hmFeatures`.

### Feature with external module (config-module)

1. **Create the module** — `home-manager/config-modules/<name>/default.nix`:
   ```nix
   { config, pkgs, inputs, ... }: {
     imports = [ inputs.ma-flake.homeModules.le-module ];
     # module-specific options...
   };
   ```

2. **Create the feature wrapper** — `home-manager/features/<name>.nix`:
   ```nix
   { inputs, ... }: {
     imports = [ (inputs.self + "/home-manager/config-modules/<name>") ];
   }
   ```

3. Add `"<name>"` to the user's features

**Why `inputs.self`?** Relative paths (`../config-modules/...`) are not resolved
correctly in the Nix store. `inputs.self + "/home-manager/..."` gives a valid absolute path.

### globalFeatures vs hmFeatures

- **`globalFeatures`** — applied to **all users** (cli, shell, desktop-core, ...)
- **`hmFeatures`** — applied to **a specific user** (gnome, development, browser, ...)

## Configuring for NixOS standalone

For a new NixOS system:

1. Add the user in `hm-profiles/users.nix` (as above)
2. The NixOS config automatically reads `userConfigs` via `configurations/configs/common/users.nix` (creates the UNIX accounts)
3. The `globalFeatures` and `hmFeatures` are passed in `specialArgs` and available in NixOS modules

## Configuring for HM standalone (non-NixOS Linux)

```bash
nix build '.#homeConfigurations.alice@x86_64-linux'
```

The `mkHome` in `flake.nix`:
- Imports `hm-profiles/users/<name>/default.nix` (same entry point as NixOS)
- Automatically adds `configs/specific/standalone` (standalone specifics)
- Adds the stylix HM module if `gnome` is in the features