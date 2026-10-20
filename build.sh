#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/build"
APP_PATH="$OUTPUT_DIR/LivePDF.app"
STAGING_DIR=""
SKIP_COMPILE=false

usage() {
    printf 'Usage: %s [--skip-compile]\n' "$0"
    printf 'Build the release executable and package build/LivePDF.app.\n'
    printf 'Use --skip-compile to reuse the executable in the existing application bundle.\n'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-compile) SKIP_COMPILE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

cleanup() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        /bin/rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'LivePDF requires macOS 14 or later.\n' >&2
    exit 1
fi

if [[ "$SKIP_COMPILE" == true ]]; then
    BINARY_PATH="$APP_PATH/Contents/MacOS/LivePDF"
    if [[ ! -x "$BINARY_PATH" ]]; then
        printf 'Cannot reuse the executable: %s. Run ./build.sh without --skip-compile first.\n' "$BINARY_PATH" >&2
        exit 1
    fi
else
    BUILD_ARGUMENTS=(--package-path "$PROJECT_ROOT" --configuration release)
    if [[ -n "${LIVEPDF_BUILD_PATH:-}" ]]; then
        BUILD_ARGUMENTS+=(--scratch-path "$LIVEPDF_BUILD_PATH")
    fi
    swift build "${BUILD_ARGUMENTS[@]}"
    BINARY_DIR="$(swift build "${BUILD_ARGUMENTS[@]}" --show-bin-path)"
    BINARY_PATH="$BINARY_DIR/LivePDF"
fi

if [[ ! -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]]; then
    if [[ ! -x "$PROJECT_ROOT/scripts/make-icon.sh" ]]; then
        printf 'Missing AppIcon.icns and executable scripts/make-icon.sh.\n' >&2
        exit 1
    fi
    "$PROJECT_ROOT/scripts/make-icon.sh"
fi
if [[ ! -s "$PROJECT_ROOT/Resources/AppIcon.icns" ]]; then
    printf 'Icon generation did not produce Resources/AppIcon.icns.\n' >&2
    exit 1
fi

for language in en zh-Hans; do
    if [[ ! -s "$PROJECT_ROOT/Resources/Localizations/$language.lproj/Localizable.strings" ]]; then
        printf 'Missing application localization: Resources/Localizations/%s.lproj/Localizable.strings\n' "$language" >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/.LivePDF-build.XXXXXX")"
STAGED_APP="$STAGING_DIR/LivePDF.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
# Copy before moving the existing app: --skip-compile reads its executable.
/usr/bin/install -m 755 "$BINARY_PATH" "$STAGED_APP/Contents/MacOS/LivePDF"
/usr/bin/install -m 644 "$PROJECT_ROOT/Resources/Info.plist" "$STAGED_APP/Contents/Info.plist"
/usr/bin/install -m 644 "$PROJECT_ROOT/Resources/AppIcon.icns" "$STAGED_APP/Contents/Resources/AppIcon.icns"
/usr/bin/install -m 644 "$PROJECT_ROOT/LICENSE" "$STAGED_APP/Contents/Resources/LICENSE"
/usr/bin/install -m 644 "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" "$STAGED_APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
for localization in "$PROJECT_ROOT/Resources/Localizations/"*.lproj; do
    [[ -d "$localization" ]] || continue
    /usr/bin/ditto --norsrc --noextattr --noacl "$localization" "$STAGED_APP/Contents/Resources/${localization##*/}"
done
printf 'APPL????' > "$STAGED_APP/Contents/PkgInfo"
/usr/bin/plutil -lint "$STAGED_APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$STAGED_APP"
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"

# Replace only this script's application bundle; other build outputs are retained.
if [[ -e "$APP_PATH" || -L "$APP_PATH" ]]; then
    /bin/mv "$APP_PATH" "$STAGING_DIR/previous.app"
fi
if ! /bin/mv "$STAGED_APP" "$APP_PATH"; then
    if [[ -e "$STAGING_DIR/previous.app" || -L "$STAGING_DIR/previous.app" ]]; then
        /bin/mv "$STAGING_DIR/previous.app" "$APP_PATH"
    fi
    exit 1
fi

printf 'Built: %s\n' "$APP_PATH"
