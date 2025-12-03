{
  lib,
  config,
  pkgs,
  zen-browser,
  ...
}:

let
  cfg = config.programs.zen-browser;
in
{
  ### Declare option
  options.programs.zen-browser = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the Zen web browser.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = zen-browser.packages."${pkgs.stdenvNoCC.hostPlatform.system}".default;
      description = "Zen browser package to use";
      defaultText = lib.literalExpression "pkgs.firefox";
    };
    enableHardening = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable hardening to the Zen web browser.";
    };
  };

  ### -- Implementation --
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Bloc principal : ajout du navigateur au système
      {
        environment.systemPackages = [ cfg.package ];
      }
      (lib.mkIf cfg.enableHardening {
        ### Add option for hardening (with firejail (like enableHardening of firefox (custom opts)))
        programs.firejail.wrappedBinaries = {
          zen = {
            ### Refer bin output with lib.getBin (see https://nixos.org/manual/nixpkgs/stable/#function-library-lib.attrsets.getBin)
            executable = "${lib.getBin config.programs.zen-browser.package}/bin/zen";
            extraArgs = [
              "--disable-mnt"
              "--private-tmp"
              "--private-dev"
              "--keep-dev-shm"
            ];
          };
          ### Add zen-beta (could be changed/removed when zen quit beta)
          zen-beta = {
            executable = config.programs.firejail.wrappedBinaries.zen.executable;
            extraArgs = config.programs.firejail.wrappedBinaries.zen.extraArgs;
          };
        };
      })
      ### Other sub-opts here
    ]
  );
}
