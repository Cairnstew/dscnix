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
          #
          # To update:
          # 1. Visit https://github.com/PowerShell/DSC/releases
          # 2. Find the latest release (e.g., v3.2.0)
          # 3. Update 'version' below (without the 'v' prefix)
          # 4. Update the sha256 by running:
          #    nix-prefetch-url https://github.com/PowerShell/DSC/releases/download/v<version>/DSC-<version>-x86_64-linux.tar.gz
          # 5. Replace the sha256 string below with the output
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

          dscSearch = pkgs.stdenvNoCC.mkDerivation {
            pname = "dsc-search";
            version = "0.1.0";
            src = ./scripts/dsc-search.sh;
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              mkdir -p $out/bin
              cp $src $out/bin/dsc-search
              chmod +x $out/bin/dsc-search
              substituteInPlace $out/bin/dsc-search \
                --replace "@CURL@" "${pkgs.curl}/bin/curl" \
                --replace "@JQ@" "${pkgs.jq}/bin/jq" \
                --replace "@PYTHON3@" "${pkgs.python3}/bin/python3"
            '';
          };

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
