#!/bin/bash
set -euo pipefail

LIVEPDF_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$LIVEPDF_ROOT"

# Some Command Line Tools releases ship Testing.framework but omit automatic
# macro-plugin discovery in SwiftPM. Use the active toolchain's own plugin.
LIVEPDF_SWIFT_BIN="$(xcrun --find swift)"
LIVEPDF_TESTING_PLUGIN="$(dirname -- "$LIVEPDF_SWIFT_BIN")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
LIVEPDF_TEST_ARGUMENTS=(test --disable-xctest)
if [[ -n "${LIVEPDF_BUILD_PATH:-}" ]]; then
    LIVEPDF_TEST_ARGUMENTS+=(--scratch-path "$LIVEPDF_BUILD_PATH")
fi
if [[ -f "$LIVEPDF_TESTING_PLUGIN" ]]; then
    LIVEPDF_TEST_ARGUMENTS+=(-Xswiftc -load-plugin-library -Xswiftc "$LIVEPDF_TESTING_PLUGIN")
fi

exec "$LIVEPDF_SWIFT_BIN" "${LIVEPDF_TEST_ARGUMENTS[@]}" "$@"
