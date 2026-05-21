{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.registry = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        keyPath = mkOption {
          type = types.str;
          description = "The path to the registry key. Must start with a valid hive identifier (HKCR, HKCU, HKLM, HKU, HKCC).";
        };
        valueName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The name of the registry value. Required when specifying valueData.";
        };
        valueData = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              String = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "REG_SZ string value.";
              };
              ExpandString = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "REG_EXPAND_SZ string value with expandable references.";
              };
              MultiString = mkOption {
                type = types.nullOr (types.listOf types.str);
                default = null;
                description = "REG_MULTI_SZ array of strings.";
              };
              Binary = mkOption {
                type = types.nullOr (types.listOf (types.ints.between 0 255));
                default = null;
                description = "REG_BINARY array of 8-bit unsigned integers.";
              };
              DWord = mkOption {
                type = types.nullOr types.ints.unsigned;
                default = null;
                description = "REG_DWORD 32-bit unsigned integer.";
              };
              QWord = mkOption {
                type = types.nullOr types.ints.unsigned;
                default = null;
                description = "REG_QWORD 64-bit unsigned integer.";
              };
            };
          });
          default = null;
          description = "Registry value data. Must specify exactly one of String, ExpandString, MultiString, Binary, DWord, or QWord.";
        };
        exist = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the registry key or value should exist.";
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Dependencies on other resources.";
        };
      };
    }));
    default = {};
    description = "Windows Registry keys and values.";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: reg: {
      "${name}" = {
        type = "Microsoft.Windows/Registry";
        properties = {
          keyPath = reg.keyPath;
          _exist = reg.exist;
        } // optionalAttrs (reg.valueName != null) {
          valueName = reg.valueName;
        } // optionalAttrs (reg.valueData != null) {
          valueData = reg.valueData;
        };
        dependsOn = reg.dependsOn;
      };
    }) cfg.registry
  );
}
