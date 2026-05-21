# AGENTS.md — dscnix

A Nix flake that generates PowerShell DSC `.ps1` files from the NixOS module system (like terranix for Terraform).

## Working in this repo

- Run all Nix commands from the `dscnix/` directory (the flake root).
- Build the example: `nix build .#example --show-trace`
- Validate the flake: `nix flake check`
- There are no tests, no CI, and no formatter config. Verification is purely `nix flake check` + `nix build`.

## Architecture

- `lib/eval.nix` — entrypoint. Calls `lib.evalModules` with `../modules/core.nix` (relative path!) plus user modules, then recursively strips `_module`, `_args`, and `null` values before calling `emit.nix`.
- `lib/emit.nix` — serializes the sanitized `dsc` attrset into a PowerShell `Configuration { … }` block. Handles bool/int/string/list → `$true`, bare, `'quoted'`, `@(…)`.
- `modules/core.nix` — top-level `dsc.*` options (`configurationName`, `nodes`, `imports`, `resources`).
- `modules/resources/*.nix` — higher-level helpers (`dsc.windowsFeatures`, `dsc.files`, `dsc.services`) that map into `dsc.resources` via `lib.mkMerge` + `mapAttrsToList`.

## Adding a new resource type

1. Create `modules/resources/<name>.nix`.
2. Import it in `modules/core.nix`.
3. Define high-level `options.dsc.<name>` and use `config.dsc.resources = mkMerge (mapAttrsToList …)` to translate into `dsc.resources` entries with `type = "…"`.
4. Resource names must be unique across all types. `emit.nix` resolves `dependsOn` as `[<Type>]Name` by looking up the dependency name in `config.dsc.resources`. If two resources share a name, the lookup is ambiguous.

## PowerShell serialization details

- `escapePsString` doubles single quotes (`'` → `''`), which is the PowerShell convention.
- Windows paths with backslashes must be written as `C:\\path` in Nix strings so that Nix preserves `C:\path` in the emitted output.
