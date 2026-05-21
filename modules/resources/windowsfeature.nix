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
      };
    }));
    default = {};
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: feature: {
      "${name}" = {
        type = "WindowsFeature";
        properties = {
          Name = name;
          Ensure = feature.ensure;
        } // optionalAttrs (feature.include != []) {
          IncludeAllSubFeature = true;
        };
      };
    }) cfg.windowsFeatures
  );
}
