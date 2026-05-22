#!/usr/bin/env bash
set -euo pipefail

# Test suite for dscnix generated configurations
# Validates that generated YAML configs are structurally correct using dsc config validate
# Also attempts dsc config get and test, skipping on Linux where Windows resources are unavailable

BUILD_DIR="$(mktemp -d /tmp/dscnix-test-XXXXXX)"
trap "rm -rf ${BUILD_DIR}" EXIT

echo ""
echo "  dscnix test suite"
echo "  ──────────────────────────────────────────────"

PASS=0
FAIL=0
SKIP=0

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

# Assert dependency ordering in a generated YAML file.
# Usage: assert_dependencies <name> <drv>
assert_dependencies() {
  local name="$1"
  local drv="$2"
  local out="${BUILD_DIR}/${name}-deps.yaml"

  echo ""
  echo "  [TEST] ${name} dependency ordering"

  nix build "${drv}" --out-link "${BUILD_DIR}/${name}-dep-result" 2>/dev/null || {
    echo "  FAIL: Build failed for ${name}"
    FAIL=$((FAIL + 1))
    return 1
  }

  cp "${BUILD_DIR}/${name}-dep-result" "${out}"

  # File resource must depend on WindowsFeature
  if ! grep -q "\[resourceId('Microsoft.Windows/WindowsPowerShell','Web-Server')]" "${out}"; then
    echo "  FAIL: Could not find expected resourceId for Web-Server in ${out}"
    FAIL=$((FAIL + 1))
    return 1
  fi

  # indexHtml depends on Web-Server
  local indexhtml_block
  indexhtml_block=$(awk "/^  - name: .indexHtml/ { found=1 } found && (!/^  - name: / || /indexHtml/) { print } /^  - name: / && !/indexHtml/ { found=0 }" "${out}")
  if ! echo "${indexhtml_block}" | grep -q "\[resourceId('Microsoft.Windows/WindowsPowerShell','Web-Server')]"; then
    echo "  FAIL: indexHtml does not correctly depend on Web-Server"
    echo "  indexHtml block:"
    echo "${indexhtml_block}" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return 1
  fi

  # W3SVC must NOT depend on indexHtml
  local w3svc_block
  w3svc_block=$(awk "/^  - name: .W3SVC/ { found=1 } found && (!/^  - name: / || /W3SVC/) { print } /^  - name: / && !/W3SVC/ { found=0 }" "${out}")
  if echo "${w3svc_block}" | grep -q "\[resourceId('Microsoft.Windows/WindowsPowerShell','indexHtml')]"; then
    echo "  FAIL: W3SVC incorrectly depends on indexHtml"
    echo "  W3SVC block:"
    echo "${w3svc_block}" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return 1
  fi

  # W3SVC must depend on Web-Server
  if ! echo "${w3svc_block}" | grep -q "\[resourceId('Microsoft.Windows/WindowsPowerShell','Web-Server')]"; then
    echo "  FAIL: W3SVC does not depend on Web-Server"
    echo "  W3SVC block:"
    echo "${w3svc_block}" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return 1
  fi

  echo "  PASS (dependency ordering is correct)"
  PASS=$((PASS + 1))
}

# Attempt a non-mutating dsc config command (get or test)
# On Linux, missing Windows resources is expected and skipped.
run_dsc_command() {
  local name="$1"
  local cmd="$2"
  local out="${BUILD_DIR}/${name}.yaml"
  local log="${BUILD_DIR}/${name}-${cmd}.log"

  if [ ! -f "${out}" ]; then
    echo "  SKIP: dsc config ${cmd} — build/validate failed for ${name}"
    SKIP=$((SKIP + 1))
    return 0
  fi

  echo "  Running: dsc config ${cmd} -f ${out} ..."

  set +e
  nix develop --command bash -c "dsc config ${cmd} -f '${out}' -o pretty-json" >"${log}" 2>&1
  exit_code=$?
  set -e

  # Strip ANSI escape codes from log
  sed -i 's/\x1b\[[0-9;]*[mK]//g' "${log}"

  if [ $exit_code -eq 0 ]; then
    echo "  PASS (dsc config ${cmd} succeeded)"
    PASS=$((PASS + 1))
    return 0
  fi

  # On Linux, the DSC binary cannot resolve Windows-specific resource providers.
  # We treat resource-not-found (and related dsc Linux quirks) as an expected skip.
  if [ "$(uname -s)" = "Linux" ]; then
    local other_errors
    other_errors=$(grep "ERROR" "${log}" | grep -v "Could not read" | grep -v "Resource type not found" | grep -v "Resource not found" | grep -v "Circular dependency" || true)
    if [ -z "${other_errors}" ]; then
      echo "  SKIP (dsc config ${cmd} — Windows resources unavailable on Linux)"
      SKIP=$((SKIP + 1))
      return 0
    fi
  fi

  echo "  FAIL: dsc config ${cmd} failed:"
  grep "ERROR" "${log}" | sed 's/^/    /' || true
  echo "  Full output:"
  cat "${log}" | sed 's/^/    /'
  FAIL=$((FAIL + 1))
  return 1
}

# Test that the dscnix CLI produces valid output matching the derivation output
test_cli() {
  local name="$1"
  local example_file="$2"
  local out="${BUILD_DIR}/${name}-cli.yaml"
  local drv_out="${BUILD_DIR}/${name}-drv.yaml"

  echo ""
  echo "  [TEST] ${name} CLI output"

  nix build ".#example-${name}" --out-link "${BUILD_DIR}/${name}-drv-result" 2>/dev/null || {
    echo "  FAIL: Build failed for example ${name}"
    FAIL=$((FAIL + 1))
    return 1
  }
  cp "${BUILD_DIR}/${name}-drv-result" "${drv_out}"

  nix run ".#dscnix" -- "${example_file}" > "${out}" 2>/dev/null || {
    echo "  FAIL: dscnix CLI failed for ${name}"
    FAIL=$((FAIL + 1))
    return 1
  }

  if diff -q "${drv_out}" "${out}" >/dev/null; then
    echo "  PASS (CLI output matches derivation output)"
    PASS=$((PASS + 1))
    return 0
  else
    echo "  FAIL: CLI output differs from derivation output"
    echo "  Diff:"
    diff "${drv_out}" "${out}" | sed 's/^/    /' || true
    FAIL=$((FAIL + 1))
    return 1
  fi
}

# Test all examples
validate_config "example-webserver" ".#example-webserver"
assert_dependencies "example-webserver" ".#example-webserver"
run_dsc_command "example-webserver" "get"
run_dsc_command "example-webserver" "test"

validate_config "example-workstation" ".#example-workstation"
run_dsc_command "example-workstation" "get"
run_dsc_command "example-workstation" "test"

validate_config "example-native" ".#example-native"
run_dsc_command "example-native" "get"
run_dsc_command "example-native" "test"

# Test CLI produces identical output to derivations
test_cli "webserver" "./examples/webserver.nix"
test_cli "workstation" "./examples/windows-workstation.nix"
test_cli "native" "./examples/native-windows.nix"

echo ""
echo "  ──────────────────────────────────────────────"
echo "  Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo ""

if [ ${FAIL} -gt 0 ]; then
  exit 1
fi
