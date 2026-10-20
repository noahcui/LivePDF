#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

LIVEPDF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVEPDF_ICON_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/LivePDF-icon.XXXXXX")"
trap '/bin/rm -rf "$LIVEPDF_ICON_TEMP"' EXIT
mkdir -p "$LIVEPDF_ICON_TEMP/AppIcon.iconset" "$LIVEPDF_ROOT/Resources"

swift "$LIVEPDF_ROOT/scripts/draw-icon.swift" "$LIVEPDF_ICON_TEMP/AppIcon.png"
for LIVEPDF_SIZE in 16 32 128 256 512; do
    /usr/bin/sips -z "$LIVEPDF_SIZE" "$LIVEPDF_SIZE" "$LIVEPDF_ICON_TEMP/AppIcon.png" \
        --out "$LIVEPDF_ICON_TEMP/AppIcon.iconset/icon_${LIVEPDF_SIZE}x${LIVEPDF_SIZE}.png" >/dev/null
    LIVEPDF_RETINA_SIZE=$((LIVEPDF_SIZE * 2))
    /usr/bin/sips -z "$LIVEPDF_RETINA_SIZE" "$LIVEPDF_RETINA_SIZE" "$LIVEPDF_ICON_TEMP/AppIcon.png" \
        --out "$LIVEPDF_ICON_TEMP/AppIcon.iconset/icon_${LIVEPDF_SIZE}x${LIVEPDF_SIZE}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$LIVEPDF_ICON_TEMP/AppIcon.iconset" -o "$LIVEPDF_ICON_TEMP/AppIcon.icns"
/usr/bin/install -m 644 "$LIVEPDF_ICON_TEMP/AppIcon.png" "$LIVEPDF_ROOT/Resources/AppIcon.png"
/usr/bin/install -m 644 "$LIVEPDF_ICON_TEMP/AppIcon.icns" "$LIVEPDF_ROOT/Resources/AppIcon.icns"
printf 'Generated: %s/Resources/AppIcon.{png,icns}\n' "$LIVEPDF_ROOT"
