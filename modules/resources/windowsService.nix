{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.windowsServices = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        displayName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The display name of the service shown in the Services console.";
        };
        description = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "A description of the service.";
        };
        status = mkOption {
          type = types.nullOr (types.enum [ "Running" "Stopped" "Paused" ]);
          default = null;
          description = "The desired status of the service.";
        };
        startType = mkOption {
          type = types.nullOr (types.enum [ "Automatic" "AutomaticDelayedStart" "Manual" "Disabled" ]);
          default = null;
          description = "The start type of the service.";
        };
        executablePath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The fully qualified path to the service binary.";
        };
        logonAccount = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The account under which the service runs.";
        };
        errorControl = mkOption {
          type = types.nullOr (types.enum [ "Ignore" "Normal" "Severe" "Critical" ]);
          default = null;
          description = "The error control level for the service.";
        };
        dependencies = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "A list of service names that this service depends on.";
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Dependencies on other resources.";
        };
      };
    }));
    default = {};
    description = "Windows services using the native DSC v3 Microsoft.Windows/Service resource.";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: svc: {
      "${name}" = {
        type = "Microsoft.Windows/Service";
        properties = {
          name = name;
        } // optionalAttrs (svc.displayName != null) {
          displayName = svc.displayName;
        } // optionalAttrs (svc.description != null) {
          description = svc.description;
        } // optionalAttrs (svc.status != null) {
          status = svc.status;
        } // optionalAttrs (svc.startType != null) {
          startType = svc.startType;
        } // optionalAttrs (svc.executablePath != null) {
          executablePath = svc.executablePath;
        } // optionalAttrs (svc.logonAccount != null) {
          logonAccount = svc.logonAccount;
        } // optionalAttrs (svc.errorControl != null) {
          errorControl = svc.errorControl;
        } // optionalAttrs (svc.dependencies != []) {
          dependencies = svc.dependencies;
        };
        dependsOn = svc.dependsOn;
      };
    }) cfg.windowsServices
  );
}
