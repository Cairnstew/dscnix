{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.firewallRules = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        description = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        applicationName = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        serviceName = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        protocol = mkOption {
          type = types.nullOr (types.ints.between 0 256);
          default = null;
          description = "IP protocol number. Common: 256 (Any), 6 (TCP), 17 (UDP), 1 (ICMPv4), 58 (ICMPv6).";
        };
        localPorts = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Comma-separated local port list.";
        };
        remotePorts = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Comma-separated remote port list.";
        };
        localAddresses = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        remoteAddresses = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        direction = mkOption {
          type = types.nullOr (types.enum [ "Inbound" "Outbound" ]);
          default = null;
        };
        action = mkOption {
          type = types.nullOr (types.enum [ "Allow" "Block" ]);
          default = null;
        };
        enabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
        profiles = mkOption {
          type = types.listOf (types.enum [ "Domain" "Private" "Public" "All" ]);
          default = [];
        };
        grouping = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        interfaceTypes = mkOption {
          type = types.listOf (types.enum [ "RemoteAccess" "Wireless" "Lan" "All" ]);
          default = [];
        };
        edgeTraversal = mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
        exist = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the rule should exist. Set to false to remove.";
        };
      };
    }));
    default = {};
    description = "Windows Firewall rules.";
  };

  config.dsc.resources = mkIf (cfg.firewallRules != {}) {
    "FirewallRules" = {
      type = "Microsoft.Windows/FirewallRuleList";
      properties = {
        rules = mapAttrsToList (name: rule:
          filterAttrs (k: v: v != null) {
            name = name;
            _exist = rule.exist;
            description = rule.description;
            applicationName = rule.applicationName;
            serviceName = rule.serviceName;
            protocol = rule.protocol;
            localPorts = rule.localPorts;
            remotePorts = rule.remotePorts;
            localAddresses = rule.localAddresses;
            remoteAddresses = rule.remoteAddresses;
            direction = rule.direction;
            action = rule.action;
            enabled = rule.enabled;
            profiles = if rule.profiles == [] then null else rule.profiles;
            grouping = rule.grouping;
            interfaceTypes = if rule.interfaceTypes == [] then null else rule.interfaceTypes;
            edgeTraversal = rule.edgeTraversal;
          }
        ) cfg.firewallRules;
      };
    };
  };
}
