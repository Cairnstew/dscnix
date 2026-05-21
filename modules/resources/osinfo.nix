{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.osInfo = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        family = mkOption {
          type = types.nullOr (types.enum [ "Linux" "macOS" "Windows" ]);
          default = null;
          description = "Assert the operating system family.";
        };
        edition = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Assert the operating system edition (e.g. 'Windows 11').";
        };
        version = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Assert the operating system version.";
        };
        architecture = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Assert the processor architecture.";
        };
        bitness = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Assert the operating system bitness (32 or 64).";
        };
      };
    }));
    default = {};
    description = "Operating system assertions (Microsoft/OSInfo). Read-only assertion resource.";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: info: {
      "${name}" = {
        type = "Microsoft/OSInfo";
        properties = {
        } // optionalAttrs (info.family != null) {
          family = info.family;
        } // optionalAttrs (info.edition != null) {
          edition = info.edition;
        } // optionalAttrs (info.version != null) {
          version = info.version;
        } // optionalAttrs (info.architecture != null) {
          architecture = info.architecture;
        } // optionalAttrs (info.bitness != null) {
          bitness = info.bitness;
        };
      };
    }) cfg.osInfo
  );
}
