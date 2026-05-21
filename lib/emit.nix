{ lib, config }:
let
  inherit (lib)
    concatStringsSep mapAttrsToList isAttrs isList isString isInt isBool
    hasAttr filterAttrs optional replaceStrings;

  escapePsString = s: replaceStrings [ "'" ] [ "''" ] s;

  psValue = v:
    if v == null then "''"
    else if isBool v then (if v then "$true" else "$false")
    else if isInt v then toString v
    else if isString v then "'${escapePsString v}'"
    else if isList v then "@(${concatStringsSep ", " (map psValue v)})"
    else "'${escapePsString (toString v)}'";

  indent = level: concatStringsSep "" (builtins.genList (x: "    ") level);

  resources = config.dsc.resources or {};

  formatDependsOn = deps:
    map (dep:
      if hasAttr dep resources
      then "[${resources.${dep}.type}]${dep}"
      else "[Unknown]${dep}"
    ) deps;

  emitResource = name: resource: level:
    let
      sp = indent level;
      props = resource.properties or {};
      deps = resource.dependsOn or [];
      filteredProps = filterAttrs (k: v: v != null) props;
      depsFormatted = formatDependsOn deps;
    in
    concatStringsSep "\n" (
      [ "${sp}${resource.type} '${name}' {" ]
      ++ (mapAttrsToList (k: v: "${sp}    ${k} = ${psValue v}") filteredProps)
      ++ (lib.optional (deps != []) "${sp}    DependsOn = ${psValue depsFormatted}")
      ++ [ "${sp}}" ]
    );

  emitNode = nodeName: level:
    let
      sp = indent level;
      resList = mapAttrsToList (name: res: emitResource name res (level + 1)) resources;
    in
    concatStringsSep "\n" (
      [ "${sp}Node '${nodeName}' {" ]
      ++ resList
      ++ [ "${sp}}" ]
    );

  emitConfiguration = cfg:
    let
      name = cfg.configurationName;
      imports = cfg.imports or [];
      nodes = cfg.nodes or [ "localhost" ];
    in
    concatStringsSep "\n" (
      [ "Configuration ${name} {" ]
      ++ (map (mod: "    Import-DscResource -ModuleName '${mod}'") imports)
      ++ [ "" ]
      ++ (map (node: emitNode node 1) nodes)
      ++ [ "}" ]
      ++ [ "" ]
      ++ [ "Start-DscConfiguration -Path '.\\' -Wait -Verbose" ]
    );
in
emitConfiguration config.dsc
