{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.windowsFeatures = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        ensure = mkOption {
          type = types.enum [ "Present" "Absent" ];
          default = "Present";
        };
        include = mkOption {
          type = types.listOf types.str;
          default = [];
        };
        exclude = mkOption {
          type = types.listOf types.str;
          default = [];
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Dependencies on other resources.";
        };
      };
    }));
    default = {};
    description = "Windows features via the Windows PowerShell 5.1 adapter (PSDscResources).";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: feature: {
      "${name}" = {
        type = "Microsoft.Windows/WindowsPowerShell";
        properties = {
          resources = [
            {
              name = name;
              type = "PSDscResources/WindowsFeature";
              properties = {
                Name = name;
                Ensure = feature.ensure;
              } // optionalAttrs (feature.include != []) {
                IncludeAllSubFeature = true;
              };
            }
          ];
        };
        dependsOn = feature.dependsOn;
      };
    }) cfg.windowsFeatures
  );
}
