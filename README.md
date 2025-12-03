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

You must temporarily disable stylix before performing the installation (VM or bare metal) (ccache need to initialize is cache before change redirect to compiler (only in new installation)).
(This may cause this type of error:
```bash
error: builder for '/nix/store/3xk33dhv7y3p1cngs9m51x96wzbz0lk5-gdm-49.2.drv' failed with exit code 1;
       last 25 log lines:
       > patching file daemon/gdm-session-worker.c
       > Hunk #1 succeeded at 1652 with fuzz 1 (offset 137 lines).
       > Hunk #2 succeeded at 1703 (offset 134 lines).
       > applying patch /nix/store/6b6b3bjf07z7sb6hpas1ragyfr31jbqn-reset-environment.patch
       > patching file daemon/gdm-wayland-session.c
       > Hunk #1 succeeded at 288 (offset 3 lines).
       > patching file daemon/gdm-x-session.c
       > Hunk #1 succeeded at 630 (offset 20 lines).
       >
       > patching script interpreter paths in build-aux/find-x-server.sh
       > build-aux/find-x-server.sh: interpreter directive changed from "#!/bin/sh" to "/nix/store/rlq03x4cwf8zn73hxaxnx0zn5q9kifls-bash-5.3p3/bin/sh"
       > Running phase: updateAutotoolsGnuConfigScriptsPhase
       > Running phase: configurePhase
[...]
```)

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
