#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

LIVEPDF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVEPDF_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$LIVEPDF_ROOT/Resources/Info.plist")"
if [[ ! "$LIVEPDF_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    printf 'Invalid version in Resources/Info.plist.\n' >&2
    exit 1
fi
mkdir -p "$LIVEPDF_ROOT/dist"
LIVEPDF_SOURCE_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/LivePDF-source.XXXXXX")"
trap '/bin/rm -rf "$LIVEPDF_SOURCE_TEMP"' EXIT
LIVEPDF_SOURCE_NAME="LivePDF-$LIVEPDF_VERSION"
mkdir -p "$LIVEPDF_SOURCE_TEMP/$LIVEPDF_SOURCE_NAME"

# An explicit allowlist prevents caches, local PDFs, credentials, and release
# binaries from accidentally becoming part of the publishable source archive.
for LIVEPDF_ENTRY in .gitignore Package.swift README.md RELEASE_NOTES.md LICENSE THIRD_PARTY_NOTICES.md \
    CONTRIBUTING.md CHANGELOG.md build.sh install.sh package.sh \
    test.sh Sources Tests Resources scripts; do
    /usr/bin/ditto --norsrc --noextattr --noacl "$LIVEPDF_ROOT/$LIVEPDF_ENTRY" \
        "$LIVEPDF_SOURCE_TEMP/$LIVEPDF_SOURCE_NAME/$LIVEPDF_ENTRY"
done
(
    cd "$LIVEPDF_SOURCE_TEMP"
    /usr/bin/env COPYFILE_DISABLE=1 /usr/bin/zip -q -r -X \
        "$LIVEPDF_SOURCE_TEMP/$LIVEPDF_SOURCE_NAME-source.zip" "$LIVEPDF_SOURCE_NAME"
)
/bin/mv -f "$LIVEPDF_SOURCE_TEMP/$LIVEPDF_SOURCE_NAME-source.zip" \
    "$LIVEPDF_ROOT/dist/$LIVEPDF_SOURCE_NAME-source.zip"
printf 'Source archive: %s/dist/%s-source.zip\n' "$LIVEPDF_ROOT" "$LIVEPDF_SOURCE_NAME"
