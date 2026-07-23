# Home Manager — Architecture & User Guide

## Architecture

```
hm-profiles/
├── users.nix                     # Source de vérité (utilisateurs + features)
├── users/entry.nix                # Point d'entrée HM partagé
├── users/minegame/
│   ├── default.nix               # Appelle entry.nix avec username + surcharges
│   ├── git.nix                    # Config git du user
│   └── apps.nix                   # Config d'apps (ghostty, fastfetch…)
├── users/matt/
│   ├── default.nix
│   ├── git.nix
│   └── apps.nix
└── users/nixos/
    └── default.nix                # Utilisateur ISO (appelle entry.nix, pas de surcharge)

home-manager/
├── features/                      # Modules d'activation (HM uniquement)
│   ├── cli.nix                    # Feature inline
│   ├── shell.nix                  # Feature inline
│   ├── desktop-core.nix           # Feature inline
│   ├── gnome.nix                  # Feature inline
│   ├── development.nix            # Wrapper → config-modules/lazyvim
│   ├── browser.nix                # Wrapper → config-modules/zen-browser
│   ├── games.nix                  # Feature inline
│   ├── multimedia.nix             # Feature inline
│   └── customization.nix          # Feature inline
├── config-modules/                # Modules externes (source de vérité)
│   ├── default.nix                # Agrégateur visuel
│   ├── lazyvim/default.nix        # Import flake + config lazyvim
│   └── zen-browser/default.nix    # Import flake + config zen-browser
└── configs/specific/standalone/   # Configs HM standalone uniquement
```

### Flux d'exécution

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

## Gérer les utilisateurs

### Ajouter un utilisateur

1. **Déclarer dans `hm-profiles/users.nix`** :
   ```nix
   users = {
     alice = {
       description = "Alice";
       hmFeatures = [ "cli" "shell" "gnome" "browser" ];
     };
   };
   ```

2. **Créer le profil HM** — `hm-profiles/users/alice/default.nix` :
   ```nix
   { globalFeatures, userConfigs, ... }:

   let
     entry = import ../entry.nix {
       inherit globalFeatures userConfigs;
       username = "alice";                    # ⚠️ DOIT correspondre à la clé dans users.nix
       featPath = ../../../home-manager/features;
     };
   in
   entry // {
     imports = entry.imports ++ [
       ./git.nix    # optionnel
       ./apps.nix   # optionnel
     ];
   }
   ```

3. **Optionnel** — Créer `git.nix` et `apps.nix` dans le même répertoire.

4. **`git add`** (obligatoire pour flakes) + build.

### Supprimer un utilisateur

1. Retirer l'entrée de `hm-profiles/users.nix`
2. Supprimer `hm-profiles/users/<name>/`
3. `git add` + build

## Gérer les features

### Feature inline (simple)

Crée `home-manager/features/<name>.nix` avec le contenu HM directement :

```nix
{ pkgs, ... }: {
  home.packages = [ pkgs.hello ];
}
```

Ajoute `"<name>"` dans `globalFeatures` ou `hmFeatures` de l'utilisateur.

### Feature avec module externe (config-module)

1. **Créer le module** — `home-manager/config-modules/<name>/default.nix` :
   ```nix
   { config, pkgs, inputs, ... }: {
     imports = [ inputs.ma-flake.homeModules.le-module ];
     # options spécifiques…
   };
   ```

2. **Créer le wrapper feature** — `home-manager/features/<name>.nix` :
   ```nix
   { inputs, ... }: {
     imports = [ (inputs.self + "/home-manager/config-modules/<name>") ];
   }
   ```

3. Ajouter `"<name>"` dans les features de l'utilisateur

**Pourquoi `inputs.self` ?** Les chemins relatifs (`../config-modules/…`) ne sont pas résolus correctement dans le store Nix. `inputs.self + "/home-manager/…"` donne un chemin absolu valide.

### globalFeatures vs hmFeatures

- **`globalFeatures`** — appliquées à **tous les utilisateurs** (cli, shell, desktop-core…)
- **`hmFeatures`** — appliquées à **un utilisateur spécifique** (gnome, development, browser…)

## Configurer pour NixOS standalone

Pour un nouveau système NixOS :

1. Ajouter l'utilisateur dans `hm-profiles/users.nix` (comme ci-dessus)
2. La config NixOS lit automatiquement `userConfigs` via `configurations/configs/common/users.nix` (créer les comptes UNIX)
3. Les `globalFeatures` et `hmFeatures` sont passées dans `specialArgs` et disponibles dans les modules NixOS

## Configurer pour HM standalone (non-NixOS Linux)

```bash
nix build '.#homeConfigurations.alice@x86_64-linux'
```

Le `mkHome` dans `flake.nix` :
- Importe `hm-profiles/users/<name>/default.nix` (même entrée que NixOS)
- Ajoute automatiquement `configs/specific/standalone` (spécificités standalone)
- Ajoute stylix HM module si `gnome` est dans les features
