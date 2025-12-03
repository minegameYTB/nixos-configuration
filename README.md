# Nixos-configuration

This configuration use a stable version of NixOS

how to install this flake: 

clone this repository (preferably in your home directory) on your NixOS installation
`git clone https://github.com/minegameytb/nixos-configuration`

How to install this flake with nixos-install ?
(on the new partition (mounted on /mnt))
```bash
### With the flake on local
#> nixos-install --flake .#<host>

### Distant flake
#> nixos-install --flake github:minegameYTB/nixos-configuration#<host>
```

# flake structure

this flake as a structure with mutiple directory

```
* nixos-configuration root 
|
 \_ configurations (all configuration that describe settings for NixOS (include flake specific modules and custom modules for this configuration))
|
 \_ home-manager (related to home-manager settings (to add package to user level))
|
 \_ pkgs (local nix expression for local packages)
|
 \_ profiles (a set of local expression to be used for a host (e.g: hp-probook will have "hp-probook" hostname while hp-240 will have "UTILISA-0SK6G4E" hostname))
|
 \_ flake.nix (local expression to describe this flake (nixpkgs version management uses flake.lock (which “fixes” package versions)))
|
\_ script (script folder)
 |
 \_ mksymlink (a simple script shell which will create a symlink into the root of home directory)
 |
 \_ update-flake (a shell script that will update the flake.lock file and create a git commit automatically)
```
