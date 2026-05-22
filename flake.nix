{
  description = "dscnix — Generate PowerShell DSC v3 YAML configurations from NixOS-style modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
    in
    {
      lib = {
        evalDscConfiguration = modules:
          import ./lib/eval.nix {
            lib = nixpkgs.lib;
            inherit modules;
          };
      };

      overlays.default = final: prev: {
        dscnix = self.packages.${prev.system}.dscnix;
      };

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # DSC binary is only available for x86_64-linux
          # See: https://github.com/PowerShell/DSC/releases
          dsc = pkgs.stdenv.mkDerivation rec {
            pname = "dsc";
            version = "3.1.0";

            src = pkgs.fetchurl {
              url = "https://github.com/PowerShell/DSC/releases/download/v${version}/DSC-${version}-x86_64-linux.tar.gz";
              sha256 = "sha256-ey/A2OUONdzYy0XWPn1GH0owI77K9JOw0jXM5t0wBN0=";
            };

            nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.installShellFiles ];
            buildInputs = [ pkgs.glibc pkgs.stdenv.cc.cc.lib ];

            unpackPhase = ''tar -xzf $src'';

            installPhase = ''
              mkdir -p $out/bin
              cp dsc $out/bin/dsc
              chmod +x $out/bin/dsc
            '';

            postFixup = ''
              installShellCompletion --cmd dsc \
                --bash <($out/bin/dsc completer bash) \
                --zsh <($out/bin/dsc completer zsh) \
                --fish <($out/bin/dsc completer fish)
            '';

            installCheckPhase = ''
              $out/bin/dsc --help >/dev/null
            '';

            doInstallCheck = true;

            meta = {
              description = "PowerShell DSC v3 cross-platform Desired State Configuration engine";
              homepage = "https://github.com/PowerShell/DSC";
              license = lib.licenses.mit;
              platforms = [ "x86_64-linux" ];
            };
          };

          dscSearch = pkgs.writeShellScriptBin "dsc-search" ''
            set -euo pipefail

            QUERY="''${1:-}"
            
            usage() {
              echo ""
              echo "  dsc-search [query]"
              echo ""
              echo "  Commands:"
              echo "    dsc-search                     show this help"
              echo "    dsc-search builtin             list built-in DSC v3 resources (from binary)"
              echo "    dsc-search builtin <term>      filter built-in resources"
              echo "    dsc-search gallery <term>      search PowerShell Gallery for DSC modules"
              echo "    dsc-search winget-dsc          list all winget-dsc community resources"
              echo "    dsc-search schemas             list available DSC v3 JSON schemas"
              echo "    dsc-search releases            list DSC v3 GitHub releases"
              echo ""
            }

            case "''${1:-help}" in

              builtin)
                FILTER="''${2:-}"
                echo ""
                echo "  Built-in DSC v3 resources (Windows)"
                echo "  ───────────────────────────────────"
                 LIST="Microsoft.Windows/Registry
Microsoft.Windows/RegistryList
Microsoft.Windows/Service
Microsoft.Windows/OptionalFeatureList
Microsoft.Windows/FeatureOnDemandList
Microsoft.Windows/FirewallRuleList
Microsoft.Windows/RebootPending
Microsoft.Windows/WindowsPowerShell
Microsoft.OpenSSH.SSHD/Subsystem
Microsoft.OpenSSH.SSHD/SubsystemList
Microsoft.OpenSSH.SSHD/Windows
Microsoft.OpenSSH.SSHD/sshd_config
Microsoft/OSInfo
Microsoft.DSC/Group
Microsoft.DSC/Assertion
Microsoft.DSC/Include
Microsoft.DSC.Transitional/RunCommandOnSet
Microsoft.DSC.Transitional/PowerShellScript
Microsoft.DSC.Transitional/WindowsPowerShellScript
Microsoft.DSC.Debug/Echo"

                MATCHES=$(echo "$LIST" | grep -i "''${FILTER}" || true)
                if [ -n "$MATCHES" ]; then
                  echo "$MATCHES" | while IFS= read -r line; do
                    echo "  $line"
                  done
                else
                  echo "  (no matches)"
                fi
                echo ""
                ;;

              gallery)
                TERM="''${2:-DSC}"
                echo ""
                echo "  PowerShell Gallery — searching: '$TERM'"
                echo "  ────────────────────────────────────────"
                ${pkgs.curl}/bin/curl -sf \
                  "https://www.powershellgallery.com/api/v2/Search()?q=tags:'DSC'+''${TERM}&\$orderby=DownloadCount+desc&\$top=20" \
                  | ${pkgs.python3}/bin/python3 -c '
import sys, xml.etree.ElementTree as ET
ns = {"d": "http://schemas.microsoft.com/ado/2007/08/dataservices",
      "m": "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata",
      "a": "http://www.w3.org/2005/Atom"}
root = ET.parse(sys.stdin).getroot()
for entry in root.findall("a:entry", ns):
    name    = entry.find("a:title", ns)
    version = entry.find(".//d:Version", ns)
    desc    = entry.find(".//d:Description", ns)
    dls     = entry.find(".//d:DownloadCount", ns)
    n = name.text    if name    is not None else "?"
    v = version.text if version is not None else "?"
    d = (desc.text or "")[:72] if desc is not None else ""
    c = dls.text     if dls     is not None else "?"
    print(f"  {n} ({v})  [{c} downloads]")
    print(f"    {d}")
                  '
                echo ""
                ;;

              winget-dsc)
                echo ""
                echo "  winget-dsc community resources (github.com/microsoft/winget-dsc)"
                echo "  ──────────────────────────────────────────────────────────────────"
                ${pkgs.curl}/bin/curl -sf \
                  "https://api.github.com/repos/microsoft/winget-dsc/contents/resources" \
                  | ${pkgs.jq}/bin/jq -r '.[] | select(.type=="dir") | .name' \
                  | while IFS= read -r module; do
                      echo ""
                      echo "  [$module]"
                      ${pkgs.curl}/bin/curl -sf \
                        "https://api.github.com/repos/microsoft/winget-dsc/contents/resources/''${module}" \
                        | ${pkgs.jq}/bin/jq -r '.[] | select(.name | endswith(".psm1")) | .name' \
                        | sed 's/^/    /'
                    done
                echo ""
                ;;

              schemas)
                echo ""
                echo "  DSC v3 JSON schemas"
                echo "  ───────────────────"
                ${pkgs.curl}/bin/curl -sf \
                  "https://api.github.com/repos/PowerShell/DSC/contents/schemas/v3" \
                  | ${pkgs.jq}/bin/jq -r '.[].name' \
                  | sed 's/^/  /'
                echo ""
                ;;

              releases)
                echo ""
                echo "  DSC v3 GitHub releases"
                echo "  ──────────────────────"
                ${pkgs.curl}/bin/curl -sf \
                  "https://api.github.com/repos/PowerShell/DSC/releases?per_page=10" \
                  | ${pkgs.jq}/bin/jq -r '.[] | "  \(.tag_name)  (\(.published_at[:10]))  \(if .prerelease then \"[pre]\" else \"[stable]\" end)"'
                echo ""
                ;;

              help|*)
                usage
                ;;
            esac
          '';

          dscnix = pkgs.stdenvNoCC.mkDerivation {
            pname = "dscnix";
            version = "0.1.0";
            src = lib.cleanSource ./.;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              mkdir -p $out/bin $out/share/nix
              cp -r $src/* $out/share/nix/
              cp $src/cli/dscnix $out/bin/dscnix
              chmod +x $out/bin/dscnix
              substituteInPlace $out/bin/dscnix \
                --replace "@DSCNIX_ROOT@" "$out/share/nix"
              wrapProgram $out/bin/dscnix --prefix PATH : ${pkgs.nix}/bin
            '';
          };

        in
        {
          inherit dscSearch dscnix;
          example-webserver = pkgs.writeText "dsc-configuration.yaml" (self.lib.evalDscConfiguration [ ./examples/webserver.nix ]);
          example-workstation = pkgs.writeText "dsc-configuration.yaml" (self.lib.evalDscConfiguration [ ./examples/windows-workstation.nix ]);
          example-native = pkgs.writeText "dsc-configuration.yaml" (self.lib.evalDscConfiguration [ ./examples/native-windows.nix ]);
        } // lib.optionalAttrs (system == "x86_64-linux") {
          inherit dsc;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.dscnix}/bin/dscnix";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "dscnix";

            packages = with pkgs; [
              self.packages.${system}.dscSearch
              self.packages.${system}.dscnix
              jq
              curl
              python3
              git
              act
            ] ++ lib.optionals (system == "x86_64-linux") [
              self.packages.${system}.dsc
            ];

            shellHook = ''
              echo ""
              echo "  dscnix dev shell  (DSC v3)"
              echo "  ──────────────────────────────────────────────"
              echo "  dscnix <module.nix>            generate DSC YAML to stdout"
              echo "  dsc-search builtin             built-in Windows resources"
              echo "  dsc-search builtin <term>      filter built-in resources"
              echo "  dsc-search gallery <term>      search PowerShell Gallery"
              echo "  dsc-search winget-dsc          winget-dsc community modules"
              echo "  dsc-search schemas             DSC v3 JSON schemas"
              echo "  dsc-search releases            recent DSC releases"
              echo ""
              echo "  dsc --help                     full CLI reference"
              echo "  dsc completer <shell>          shell completions (bash, zsh, fish)"
              echo ""
              echo "  Available Nix resource options:"
              echo "    dsc.registry                 Microsoft.Windows/Registry"
              echo "    dsc.windowsServices          Microsoft.Windows/Service"
              echo "    dsc.firewallRules            Microsoft.Windows/FirewallRuleList"
              echo "    dsc.optionalFeatures           Microsoft.Windows/OptionalFeatureList"
              echo "    dsc.featuresOnDemand           Microsoft.Windows/FeatureOnDemandList"
              echo "    dsc.runCommands                Microsoft.DSC.Transitional/RunCommandOnSet"
              echo "    dsc.powerShellScripts          Microsoft.DSC.Transitional/PowerShellScript"
              echo "    dsc.windowsPowerShellScripts   Microsoft.DSC.Transitional/WindowsPowerShellScript"
              echo "    dsc.osInfo                     Microsoft/OSInfo"
              echo "    dsc.rebootPending              Microsoft.Windows/RebootPending"
              echo "    dsc.windowsFeatures            WindowsFeature (PSDscResources)"
              echo "    dsc.files                      File (PSDscResources)"
              echo "    dsc.services                   Service (PSDscResources)"
              echo ""
            '';
          };
        });
    };
}
