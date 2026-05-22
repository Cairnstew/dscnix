# dscnix

A **Nix flake** that generates [DSC v3](https://github.com/PowerShell/DSC) YAML configuration documents from the NixOS module system — like *terranix* for Terraform, but for PowerShell Desired State Configuration.

Define your Windows infrastructure declaratively in Nix, and get a validated DSC v3 YAML document that you can run with `dsc config set`.

## Features

- **Declarative Windows configuration** — Manage features, services, registry keys, firewall rules, files, and more using familiar Nix syntax.
- **Native DSC v3 resources** — Emits modern `Microsoft.Windows/*` and `Microsoft.DSC/*` resource types.
- **Legacy PSDscResources support** — Classic `WindowsFeature`, `File`, and `Service` resources are automatically wrapped in the `Microsoft.Windows/WindowsPowerShell` adapter.
- **Dependency resolution** — `dependsOn` between resources is automatically translated to DSC v3 `[resourceId('Type','Name')]` syntax.
- **CLI and library API** — Use the `dscnix` command-line tool, import the flake as a library, or run it remotely with `nix run`.
- **Validation** — Built-in test suite checks that generated YAML is structurally valid using the official `dsc` binary.

## Quick Start

### Using the CLI

```bash
# Generate a DSC YAML configuration from a Nix module
nix run github:Cairnstew/dscnix -- ./my-config.nix > output.yaml

# Or install locally
nix build .#dscnix
./result/bin/dscnix ./my-config.nix > output.yaml
```

### Using as a flake library

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

## Examples

### Web server (legacy PSDscResources)

```nix
{ config, lib, ... }:
with lib;
{
  dsc = {
    configurationName = "WebServer";

    windowsFeatures = {
      "Web-Server" = {
        ensure = "Present";
      };
    };

    files = {
      indexHtml = {
        ensure = "Present";
        sourcePath = "C:\\Source\\index.html";
        destinationPath = "C:\\inetpub\\wwwroot\\index.html";
        dependsOn = [ "Web-Server" ];
      };
    };

    services = {
      W3SVC = {
        ensure = "Present";
        state = "Running";
        dependsOn = [ "Web-Server" ];
      };
    };
  };
}
```

### Native Windows resources

```nix
{ config, lib, ... }:
with lib;
{
  dsc = {
    configurationName = "NativeWindowsConfig";

    registry = {
      "DarkMode" = {
        keyPath = "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
        valueName = "AppsUseLightTheme";
        valueData = { DWord = 0; };
      };
    };

    windowsServices = {
      "Audiosrv" = {
        status = "Running";
        startType = "Automatic";
      };
    };

    firewallRules = {
      "AllowRDP" = {
        direction = "Inbound";
        action = "Allow";
        protocol = 6;
        localPorts = "3389";
        enabled = true;
        profiles = [ "Domain" "Private" ];
      };
    };
  };
}
```

See the [`examples/`](./examples/) directory for more reference configurations.

## Supported Resources

| Nix option | DSC v3 resource type | Category | Notes |
|---|---|---|---|
| `dsc.registry` | `Microsoft.Windows/Registry` | Native | Settable |
| `dsc.windowsServices` | `Microsoft.Windows/Service` | Native | Settable |
| `dsc.firewallRules` | `Microsoft.Windows/FirewallRuleList` | Native | **Read-only** (Get/Test only) |
| `dsc.optionalFeatures` | `Microsoft.Windows/OptionalFeatureList` | Native | **Read-only** (Get/Test only) |
| `dsc.featuresOnDemand` | `Microsoft.Windows/FeatureOnDemandList` | Native | **Read-only** (Get/Test only) |
| `dsc.runCommands` | `Microsoft.DSC.Transitional/RunCommandOnSet` | Native | Settable |
| `dsc.powerShellScripts` | `Microsoft.DSC.Transitional/PowerShellScript` | Native | Settable |
| `dsc.windowsPowerShellScripts` | `Microsoft.DSC.Transitional/WindowsPowerShellScript` | Native | Settable |
| `dsc.osInfo` | `Microsoft/OSInfo` | Native | Read-only |
| `dsc.rebootPending` | `Microsoft.Windows/RebootPending` | Native | Read-only |
| `dsc.windowsFeatures` | `PSDscResources/WindowsFeature` | Legacy (wrapped) | Settable |
| `dsc.files` | `PSDesiredStateConfiguration/File` | Legacy (wrapped) | Settable |
| `dsc.services` | `PSDesiredStateConfiguration/Service` | Legacy (wrapped) | Settable |

## Development

### Build and validate

```bash
# Enter the development shell
nix develop

# Validate the flake
nix flake check

# Build an example
nix build .#examples.webserver --show-trace

# Run the test suite
./tests/validate.sh
```

### Helper tools

The dev shell includes `dsc-search`, a small helper for discovering DSC resources:

```bash
dsc-search builtin              # List built-in Windows resources
dsc-search builtin registry     # Filter by name
dsc-search gallery SSH          # Search PowerShell Gallery
dsc-search winget-dsc           # List winget-dsc community modules
dsc-search schemas              # List DSC v3 JSON schemas
dsc-search releases             # List recent DSC releases
```

## Architecture

- **`lib/eval.nix`** — Entrypoint. Evaluates user modules via `lib.evalModules` and sanitizes the result before emission.
- **`lib/emit.nix`** — Serializes the `dsc` attrset into a DSC v3 YAML document (`$schema`, `resources:` list).
- **`modules/core.nix`** — Top-level `dsc.*` options (`configurationName`, `nodes`, `imports`, `resources`).
- **`modules/resources/*.nix`** — Higher-level helpers that translate Nix declarations into `dsc.resources` entries.
- **`cli/dscnix`** — Shell script wrapping `nix eval` to produce YAML on stdout.

## Contributing

This project is early-stage and welcomes contributions. To add a new resource type:

1. Create `modules/resources/<name>.nix`.
2. Import it in `modules/core.nix`.
3. Define high-level `options.dsc.<name>` and map it into `dsc.resources` using `lib.mkMerge` + `mapAttrsToList`.
4. Ensure resource names remain unique across all types (see `emit.nix` for `dependsOn` resolution).

## License

MIT
