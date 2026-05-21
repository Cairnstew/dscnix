#!/usr/bin/env bash
set -euo pipefail

# Test suite for dscnix generated configurations
# Validates that generated YAML configs are structurally correct using dsc config validate

BUILD_DIR="$(mktemp -d /tmp/dscnix-test-XXXXXX)"
trap "rm -rf ${BUILD_DIR}" EXIT

echo ""
echo "  dscnix test suite"
echo "  ──────────────────────────────────────────────"

PASS=0
FAIL=0

# Validate a nix build output using dsc config validate
validate_config() {
  local name="$1"
  local drv="$2"
  local out="${BUILD_DIR}/${name}.yaml"
  local log="${BUILD_DIR}/${name}-validate.log"

  echo ""
  echo "  [TEST] ${name}"
  echo "  Building derivation ${drv}..."

  # Build and copy result
  nix build "${drv}" --out-link "${BUILD_DIR}/${name}-result" 2>/dev/null || {
    echo "  FAIL: Build failed for ${name}"
    FAIL=$((FAIL + 1))
    return 1
  }

  cp "${BUILD_DIR}/${name}-result" "${out}"

  echo "  Running: dsc config validate -f ${out} ..."

  # dsc config validate will fail on Linux for Windows-specific resources
  # because the resource binaries aren't installed. We accept "Resource type not found"
  # and "Resource not found" errors but reject parser/structural errors.
  set +e
  nix develop --command bash -c "dsc config validate -f '${out}' -o pretty-json" >"${log}" 2>&1
  exit_code=$?
  set -e

  # Strip ANSI escape codes from log
  sed -i 's/\x1b\[[0-9;]*[mK]//g' "${log}"

  # Check for structural/schema errors (excluding harmless logs and "Resource not found")
  structural_errors=$(grep "ERROR" "${log}" | grep -v "Could not read" | grep -v "Resource type not found" | grep -v "Resource not found" || true)

  if [ -n "${structural_errors}" ]; then
    echo "  FAIL: Structural/schema errors detected:"
    echo "${structural_errors}" | sed 's/^/    /'
    echo "  Full output:"
    cat "${log}" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Also check for parser errors (like "Unable to parse statement" or "Circular dependency")
  parser_errors=$(grep -E "Parser:|Circular dependency|Failed validation.*Configuration" "${log}" || true)

  if [ -n "${parser_errors}" ]; then
    echo "  FAIL: Parser/validation errors detected:"
    echo "${parser_errors}" | sed 's/^/    /'
    echo "  Full output:"
    cat "${log}" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Check if the YAML itself is valid by trying to read it with dsc
  # Even if resources aren't found, the document structure should be valid
  if grep -q '"valid": false' "${log}"; then
    # It's OK if the only failure is missing resources on Linux
    if grep -q "Resource type not found" "${log}"; then
      echo "  PASS (structurally valid; resource resolution skipped on Linux)"
      PASS=$((PASS + 1))
      return 0
    fi
    if grep -q "Resource not found" "${log}"; then
      echo "  PASS (structurally valid; resource resolution skipped on Linux)"
      PASS=$((PASS + 1))
      return 0
    fi
    echo "  FAIL: validation returned false for unknown reason"
    cat "${log}" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return 1
  fi

  if grep -q '"valid": true' "${log}"; then
    echo "  PASS (fully validated)"
    PASS=$((PASS + 1))
    return 0
  fi

  echo "  FAIL: Unexpected validation output"
  cat "${log}" | sed 's/^/    /'
  FAIL=$((FAIL + 1))
  return 1
}

# Test all examples
validate_config "example-webserver" ".#example"
validate_config "example-workstation" ".#exampleWorkstation"
validate_config "example-native" ".#exampleNative"

echo ""
echo "  ──────────────────────────────────────────────"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo ""

if [ ${FAIL} -gt 0 ]; then
  exit 1
fi
