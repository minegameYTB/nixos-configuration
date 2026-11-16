### opencode additions on NixOS, gated on the system installation of REA so
### machines without the AI tooling stay untouched.
{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  ### NUR evaluates the repo with the consumer's nixpkgs, so these store paths
  ### match the ones the rea-ghidra wrapper carries on this machine.
  rea = (pkgs.nur.repos.minegameYTB or { }).rea-ghidra or null;
  reaInstalled =
    rea != null
    && builtins.any (p: (p.outPath or "") == rea.outPath) (osConfig.environment.systemPackages or [ ]);
in
lib.mkIf reaInstalled {
  ### opencode merges MCP servers per server name across every config file
  ### (global json/jsonc, project, OPENCODE_CONFIG, /etc), so this file only
  ### adds `rea` beside the servers of the shared dotfiles config.
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    mcp.servers.rea = {
      type = "local";
      command = [
        "rea"
        "mcp"
      ];
      ### Recorded so `rea doctor` reports a complete registration; the
      ### wrapper exports the same values at runtime anyway. The optionalAttrs
      ### mirror the rea-ghidra package's own ghidra/jdk25 gates.
      environment =
        lib.optionalAttrs (pkgs ? jdk25) {
          JAVA_HOME = "${pkgs.jdk25}/lib/openjdk";
        }
        // lib.optionalAttrs (pkgs ? ghidra) {
          GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";
        };
    };
  };

  ### The REA skill as regular files: REA's own checks reject the symlinks
  ### home-manager would create, and opencode discovers ~/.agents/skills as a
  ### global compatibility source. Re-copied whenever the package changes.
  home.activation.install-rea-skill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ### Scoped PATH: clobbering it would affect later activation steps
    (
      PATH="${pkgs.coreutils}/bin:$PATH"
      reaSkillSrc="${rea}/lib/node_modules/rea-agents/skills/reverse-engineer-anything"
      reaSkillDest="$HOME/.agents/skills/reverse-engineer-anything"

      ### Skip when the installed bundle already matches the package
      if ! cmp -s "$reaSkillSrc/SKILL.md" "$reaSkillDest/SKILL.md" 2>/dev/null; then
        mkdir -p "$HOME/.agents/skills"
        rm -rf "$reaSkillDest"
        cp -r "$reaSkillSrc" "$reaSkillDest"
        chmod -R u+w "$reaSkillDest"
      fi
    )
  '';
}
