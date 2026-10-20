#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$PROJECT_ROOT/build/LivePDF.app"
INSTALLER_RESOURCES="$PROJECT_ROOT/Resources/Installer"
DIST_DIR="$PROJECT_ROOT/dist"
STAGING_DIR=""
SKIP_BUILD=false

usage() {
    printf 'Usage: %s [--skip-build]\n' "$0"
    printf 'Build an unsigned arm64 installer for macOS 14 or later.\n'
    printf 'Use --skip-build to package the existing build/LivePDF.app.\n'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=true; shift ;;
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
    printf 'Packaging LivePDF requires macOS.\n' >&2
    exit 1
fi
if [[ "$SKIP_BUILD" == false ]]; then
    "$PROJECT_ROOT/build.sh"
fi

if [[ ! -x "$APP_PATH/Contents/MacOS/LivePDF" || ! -f "$APP_PATH/Contents/Info.plist" ]]; then
    printf 'Missing application bundle: %s. Run ./build.sh first.\n' "$APP_PATH" >&2
    exit 1
fi
/usr/bin/plutil -lint "$APP_PATH/Contents/Info.plist"
/usr/bin/lipo -verify_arch arm64 "$APP_PATH/Contents/MacOS/LivePDF"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ || "$BUNDLE_ID" != 'com.noah.LivePDF' ]]; then
    printf 'Unexpected LivePDF bundle version or identifier.\n' >&2
    exit 1
fi

for language in en zh-Hans; do
    if [[ ! -s "$INSTALLER_RESOURCES/UI/$language.lproj/ReadMe.html" || ! -s "$INSTALLER_RESOURCES/UI/$language.lproj/Localizable.strings" ]]; then
        printf 'Missing installer localization: %s\n' "$language" >&2
        exit 1
    fi
    /usr/bin/plutil -lint "$INSTALLER_RESOURCES/UI/$language.lproj/Localizable.strings"
done

mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d "$DIST_DIR/.LivePDF-package.XXXXXX")"
PAYLOAD_ROOT="$STAGING_DIR/payload"
mkdir -p "$PAYLOAD_ROOT/Applications" "$PAYLOAD_ROOT/usr/local/bin"
# Only the release application and this fixed launcher enter the payload.
# Omit build-machine ACLs, Finder metadata, and extended attributes.
/usr/bin/ditto --norsrc --noextattr --noacl "$APP_PATH" "$PAYLOAD_ROOT/Applications/LivePDF.app"
/usr/bin/install -m 755 "$INSTALLER_RESOURCES/livepdf" "$PAYLOAD_ROOT/usr/local/bin/livepdf"
/bin/chmod -R u=rwX,go=rX "$PAYLOAD_ROOT/Applications/LivePDF.app"
/bin/chmod 755 "$PAYLOAD_ROOT" "$PAYLOAD_ROOT/Applications" "$PAYLOAD_ROOT/usr" "$PAYLOAD_ROOT/usr/local" "$PAYLOAD_ROOT/usr/local/bin"

# Swift's linker signs the executable alone. Seal the complete app bundle for
# transport to another Apple Silicon Mac, using a local ad-hoc identity only.
# No developer certificate, keychain access, or notarization service is needed.
/usr/bin/codesign --force --sign - --timestamp=none "$PAYLOAD_ROOT/Applications/LivePDF.app"
/usr/bin/codesign --verify --deep --strict "$PAYLOAD_ROOT/Applications/LivePDF.app"

/usr/bin/sed "s/@VERSION@/$VERSION/g" "$INSTALLER_RESOURCES/Distribution.xml.in" > "$STAGING_DIR/Distribution.xml"
/usr/bin/xmllint --noout "$STAGING_DIR/Distribution.xml"
/usr/bin/plutil -lint "$INSTALLER_RESOURCES/Components.plist"

/usr/bin/env COPYFILE_DISABLE=1 /usr/bin/pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier 'com.noah.LivePDF.pkg' \
    --version "$VERSION" \
    --install-location / \
    --ownership recommended \
    --component-plist "$INSTALLER_RESOURCES/Components.plist" \
    --min-os-version 14.0 \
    --compression legacy \
    "$STAGING_DIR/LivePDF-component.pkg"

PACKAGE_NAME="LivePDF-$VERSION-arm64.pkg"
/usr/bin/productbuild \
    --distribution "$STAGING_DIR/Distribution.xml" \
    --package-path "$STAGING_DIR" \
    --resources "$INSTALLER_RESOURCES/UI" \
    "$STAGING_DIR/$PACKAGE_NAME"

if [[ -d "$DIST_DIR/$PACKAGE_NAME" ]]; then
    printf 'Cannot replace a directory with the installer: %s\n' "$DIST_DIR/$PACKAGE_NAME" >&2
    exit 1
fi
/bin/mv -f "$STAGING_DIR/$PACKAGE_NAME" "$DIST_DIR/$PACKAGE_NAME"
printf 'Packaged: %s\n' "$DIST_DIR/$PACKAGE_NAME"
