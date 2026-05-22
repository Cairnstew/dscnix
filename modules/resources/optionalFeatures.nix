{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.optionalFeatures = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        state = mkOption {
          type = types.enum [ "Installed" "NotPresent" "Removed" ];
          description = "Desired state of the optional feature. Only Installed, NotPresent, and Removed are valid for set.";
        };
        displayName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Display name filter for export.";
        };
        description = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Description filter for export.";
        };
      };
    }));
    default = {};
    description = "Windows Optional Features using DISM (Microsoft.Windows/OptionalFeatureList). NOTE: This resource is read-only (Get/Test only) in DSC v3.1.0. Cannot set state.";
  };

  config.dsc.resources = mkIf (cfg.optionalFeatures != {}) {
    "OptionalFeatures" = {
      type = "Microsoft.Windows/OptionalFeatureList";
      properties = {
        features = mapAttrsToList (name: feature: {
          featureName = name;
          state = feature.state;
        } // optionalAttrs (feature.displayName != null) {
          displayName = feature.displayName;
        } // optionalAttrs (feature.description != null) {
          description = feature.description;
        }) cfg.optionalFeatures;
      };
    };
  };
}
