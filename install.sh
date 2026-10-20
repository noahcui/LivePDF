#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications"
APP_PATH="$APP_DIR/LivePDF.app"
STAGING_DIR=""

usage() {
    printf 'Usage: %s [--bin-dir DIRECTORY]\n' "$0"
    printf 'Build and install LivePDF.app in ~/Applications and livepdf in ~/.local/bin.\n'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bin-dir)
            if [[ $# -lt 2 || -z "$2" ]]; then
                printf '%s\n' '--bin-dir requires a directory.' >&2
                exit 1
            fi
            BIN_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done

cleanup() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        /bin/rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

"$PROJECT_ROOT/build.sh"
mkdir -p "$APP_DIR" "$BIN_DIR"
BIN_DIR="$(cd "$BIN_DIR" && pwd)"
STAGING_DIR="$(mktemp -d "$APP_DIR/.LivePDF-install.XXXXXX")"
/usr/bin/ditto "$PROJECT_ROOT/build/LivePDF.app" "$STAGING_DIR/LivePDF.app"

if [[ -e "$APP_PATH" || -L "$APP_PATH" ]]; then
    /bin/mv "$APP_PATH" "$STAGING_DIR/previous.app"
fi
if ! /bin/mv "$STAGING_DIR/LivePDF.app" "$APP_PATH"; then
    if [[ -e "$STAGING_DIR/previous.app" || -L "$STAGING_DIR/previous.app" ]]; then
        /bin/mv "$STAGING_DIR/previous.app" "$APP_PATH"
    fi
    exit 1
fi

# %q creates a shell-safe assignment, including when HOME contains spaces.
{
    printf '#!/bin/bash\n'
    printf 'APP_PATH=%q\n' "$APP_PATH"
    printf 'exec /usr/bin/open -a "$APP_PATH" -- "$@"\n'
} > "$STAGING_DIR/livepdf"
/usr/bin/install -m 755 "$STAGING_DIR/livepdf" "$BIN_DIR/livepdf"

LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
if [[ -x "$LSREGISTER" ]]; then
    if ! "$LSREGISTER" -f "$APP_PATH"; then
        printf 'Note: Finder registration failed; opening LivePDF.app once will register it.\n' >&2
    fi
fi

printf 'Installed: %s\nCommand: %s/livepdf\n' "$APP_PATH" "$BIN_DIR"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) printf 'Add this directory to your PATH: %s\n' "$BIN_DIR" ;;
esac
