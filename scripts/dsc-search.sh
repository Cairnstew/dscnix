#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:-}"

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

case "${1:-help}" in

  builtin)
    FILTER="${2:-}"
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

    MATCHES=$(echo "$LIST" | grep -i "${FILTER}" || true)
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
    TERM="${2:-DSC}"
    echo ""
    echo "  PowerShell Gallery — searching: '$TERM'"
    echo "  ────────────────────────────────────────"
    @CURL@ -sf \
      "https://www.powershellgallery.com/api/v2/Search()?q=tags:'DSC'+'${TERM}'&\$orderby=DownloadCount+desc&\$top=20" \
      | @PYTHON3@ -c '
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
    @CURL@ -sf \
      "https://api.github.com/repos/microsoft/winget-dsc/contents/resources" \
      | @JQ@ -r '.[] | select(.type=="dir") | .name' \
      | while IFS= read -r module; do
          echo ""
          echo "  [$module]"
          @CURL@ -sf \
            "https://api.github.com/repos/microsoft/winget-dsc/contents/resources/${module}" \
            | @JQ@ -r '.[] | select(.name | endswith(".psm1")) | .name' \
            | sed 's/^/    /'
        done
    echo ""
    ;;

  schemas)
    echo ""
    echo "  DSC v3 JSON schemas"
    echo "  ───────────────────"
    @CURL@ -sf \
      "https://api.github.com/repos/PowerShell/DSC/contents/schemas/v3" \
      | @JQ@ -r '.[].name' \
      | sed 's/^/  /'
    echo ""
    ;;

  releases)
    echo ""
    echo "  DSC v3 GitHub releases"
    echo "  ──────────────────────"
    @CURL@ -sf \
      "https://api.github.com/repos/PowerShell/DSC/releases?per_page=10" \
      | @JQ@ -r '.[] | "  \(.tag_name)  (\(.published_at[:10]))  \(if .prerelease then \"[pre]\" else \"[stable]\" end)"'
    echo ""
    ;;

  help|*)
    usage
    ;;
esac
