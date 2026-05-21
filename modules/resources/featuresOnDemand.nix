{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.featuresOnDemand = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        state = mkOption {
          type = types.enum [ "Installed" "NotPresent" ];
          description = "Desired state of the capability. Only Installed and NotPresent are valid for set.";
        };
        displayName = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        description = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
      };
    }));
    default = {};
    description = "Windows Features on Demand (capabilities) using DISM (Microsoft.Windows/FeatureOnDemandList).";
  };

  config.dsc.resources = mkIf (cfg.featuresOnDemand != {}) {
    "FeaturesOnDemand" = {
      type = "Microsoft.Windows/FeatureOnDemandList";
      properties = {
        capabilities = mapAttrsToList (name: cap: {
          identity = name;
          state = cap.state;
        } // optionalAttrs (cap.displayName != null) {
          displayName = cap.displayName;
        } // optionalAttrs (cap.description != null) {
          description = cap.description;
        }) cfg.featuresOnDemand;
      };
    };
  };
}
