{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.files = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        ensure = mkOption {
          type = types.enum [ "Present" "Absent" ];
          default = "Present";
        };
        sourcePath = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        destinationPath = mkOption {
          type = types.str;
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Dependencies on other resources.";
        };
      };
    }));
    default = {};
    description = "File resources via the Windows PowerShell 5.1 adapter (PSDesiredStateConfiguration).";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: file: {
      "${name}" = {
        type = "Microsoft.Windows/WindowsPowerShell";
        properties = {
          resources = [
            {
              name = name;
              type = "PSDesiredStateConfiguration/File";
              properties = {
                DestinationPath = file.destinationPath;
                Ensure = file.ensure;
              } // optionalAttrs (file.sourcePath != null) {
                SourcePath = file.sourcePath;
              };
            }
          ];
        };
        dependsOn = file.dependsOn;
      };
    }) cfg.files
  );
}
