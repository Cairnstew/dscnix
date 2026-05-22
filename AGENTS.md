# AGENTS.md — dscnix

A Nix flake that generates **DSC v3 YAML** configuration documents from the NixOS module system (like terranix for Terraform).

## Working in this repo

- Run all Nix commands from the `dscnix/` directory (the flake root).
- Build an example: `nix build .#examples.webserver --show-trace`
- Run the CLI: `nix run .#dscnix -- ./examples/webserver.nix > output.yaml`
- Or install the CLI: `nix build .#dscnix && ./result/bin/dscnix ./my-config.nix > output.yaml`
- Validate the flake: `nix flake check`
- Run the test suite: `./tests/validate.sh`
- There is no CI or formatter config. Verification is `nix flake check` + `nix build` + `./tests/validate.sh`.

## Using in another flake

```nix
{
  inputs.dscnix.url = "github:Cairnstew/dscnix";

  outputs = { self, nixpkgs, dscnix }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux.myConfig = pkgs.writeText "config.yaml"
        (dscnix.lib.evalDscConfiguration [ ./my-module.nix ]);
    };
}
```

Or via the CLI from another repo:
```bash
nix run github:Cairnstew/dscnix -- ./my-config.nix > output.yaml
```

## Architecture

- `lib/eval.nix` — entrypoint. Calls `lib.evalModules` with `../modules/core.nix` (relative path!) plus user modules, then recursively strips `_module`, `_args`, and `null` values before calling `emit.nix`.
- `lib/emit.nix` — serializes the sanitized `dsc` attrset into a **DSC v3 YAML** document (`$schema`, `resources:` list). Handles bool/int/string/list/attrs → YAML scalars, sequences, and mappings.
- `modules/core.nix` — top-level `dsc.*` options (`configurationName`, `nodes`, `imports`, `resources`).
  - `configurationName` is emitted as a YAML comment header.
  - `nodes` and `imports` are legacy PowerShell DSC concepts and are **not** emitted in YAML output.
- `modules/resources/*.nix` — higher-level helpers that map into `dsc.resources` via `lib.mkMerge` + `mapAttrsToList`.
  - Legacy PSDscResources: `dsc.windowsFeatures`, `dsc.files`, `dsc.services` (wrapped in `Microsoft.Windows/WindowsPowerShell` adapter)
  - Native DSC v3: `dsc.registry`, `dsc.windowsServices`, `dsc.firewallRules`, `dsc.optionalFeatures`, `dsc.featuresOnDemand`, `dsc.runCommands`, `dsc.powerShellScripts`, `dsc.windowsPowerShellScripts`, `dsc.osInfo`, `dsc.rebootPending`
- `cli/dscnix` — shell script that wraps `nix-instantiate --eval --json` to evaluate user modules and print YAML to stdout.
- `examples/` — reference configurations that demonstrate all supported resource types.

## Adding a new resource type

1. Create `modules/resources/<name>.nix`.
2. Import it in `modules/core.nix`.
3. Define high-level `options.dsc.<name>` and use `config.dsc.resources = mkMerge (mapAttrsToList …)` to translate into `dsc.resources` entries with `type = "…"`.
4. Resource names must be unique across all types. `emit.nix` resolves `dependsOn` as `[resourceId('Type','Name')]` by looking up the dependency name in `config.dsc.resources`.

## YAML serialization details

- All strings are single-quoted in YAML (`'…'`). Single quotes inside are escaped by doubling (`''`).
- Windows paths with backslashes are preserved literally because single-quoted YAML strings do not interpret escape sequences. Write `C:\path` in Nix strings and the YAML output will contain `C:\path`.
- Nested objects (e.g., `valueData`, `rules`) and lists (e.g., `profiles`, `features`) are emitted as YAML block mappings and sequences.
- `dependsOn` uses the DSC v3 `[resourceId('Type','Name')]` syntax.

## Legacy PowerShell DSC resources

Classic MOF-based resources (WindowsFeature, File, Service) are automatically wrapped in a `Microsoft.Windows/WindowsPowerShell` adapter block so they can coexist with native DSC v3 resources in the same YAML document. The inner resource types use `PSDscResources/WindowsFeature`, `PSDesiredStateConfiguration/File`, and `PSDesiredStateConfiguration/Service`.

## Read-only resources in DSC v3.1.0

The following resources are **read-only** (support Get/Test operations only) and cannot be used to set state:

- `Microsoft.Windows/FirewallRuleList` - Use for auditing only
- `Microsoft.Windows/OptionalFeatureList` - Use for auditing only  
- `Microsoft.Windows/FeatureOnDemandList` - Use for auditing only
- `Microsoft.Windows/RebootPending` - Assertion resource only
- `Microsoft/OSInfo` - Assertion resource only

To use read-only resources for assertions, wrap them in a `Microsoft.DSC/Assertion` block.

## OpenSSH resources dependency

The `Microsoft.OpenSSH.SSHD/*` resources require the OpenSSH optional feature to be installed on Windows. They are not available by default.
