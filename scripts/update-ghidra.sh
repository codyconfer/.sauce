#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

# Ghidra isn't in the Debian/Fedora repos; it ships as a single GitHub release zip and
# needs a JDK 21+. We extract it under $OPT and expose a `ghidra` launcher on PATH.
INSTALL_DIR="$OPT/ghidra"
LAUNCHER="$BIN/ghidra"
API="https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest"

cleanup() {
    log_clean "Removing Ghidra..."
    remove_paths "$INSTALL_DIR" "$LAUNCHER"
    remove_stamp ghidra
    log_done "Ghidra removed."
    log_hint "The JDK installed for Ghidra was left in place; remove it with your package manager if unused."
}
dispatch_remove "$@"

log_search "Fetching the latest Ghidra version..."
META=$(fetch "$API")
VERSION=$(echo "$META" | jq -r '.tag_name')
URL=$(echo "$META" | jq -r '.assets[] | select(.name | test("ghidra_.*_PUBLIC_.*\\.zip$")) | .browser_download_url' | head -n1)
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ] || [ -z "$URL" ]; then
    log_error "Could not resolve the latest Ghidra release."
    exit 1
fi
log_found "Latest version found: $VERSION"

# The release ships no version binary; compare the release tag against the last install.
if [ -z "${FORCE:-}" ] && [ -x "$INSTALL_DIR/ghidraRun" ] && [ "$(read_stamp ghidra)" = "$VERSION" ]; then
    log_done "Ghidra $VERSION is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

# Ghidra needs a JDK 21+; install one per-family if the current java is missing/older.
have_jdk21() {
    command -v java >/dev/null 2>&1 || return 1
    local major
    major=$(java -version 2>&1 | grep -oE 'version "[0-9]+' | grep -oE '[0-9]+' | head -1)
    [ -n "$major" ] && [ "$major" -ge 21 ]
}
if ! have_jdk21; then
    log_install "Installing a JDK (Ghidra needs 21+)..."
    case "$(detect_family)" in
        debian) install_pkgs openjdk-21-jdk || install_pkgs default-jdk || log_warn "JDK install failed." ;;
        fedora) install_pkgs java-21-openjdk-devel || install_pkgs java-latest-openjdk-devel || log_warn "JDK install failed." ;;
        arch)   install_pkgs jdk21-openjdk || install_pkgs jdk-openjdk || log_warn "JDK install failed." ;;
        *)      log_warn "Unknown distro — install a JDK 21+ manually for Ghidra." ;;
    esac
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading Ghidra $VERSION (large)..."
download "$URL" "$TMPDIR/ghidra.zip"

log_install "Extracting to $INSTALL_DIR..."
unzip -q "$TMPDIR/ghidra.zip" -d "$TMPDIR"
SRC=$(find "$TMPDIR" -maxdepth 1 -type d -name 'ghidra_*_PUBLIC' | head -n1)
[ -n "$SRC" ] || { log_error "Unexpected archive layout (no ghidra_*_PUBLIC dir)."; exit 1; }
rm -rf "$INSTALL_DIR"
ensure_dir "$(dirname "$INSTALL_DIR")"
mv "$SRC" "$INSTALL_DIR"

ensure_dir "$BIN"
ln -sf "$INSTALL_DIR/ghidraRun" "$LAUNCHER"
write_stamp ghidra "$VERSION"

log_done
log_hint "Launch Ghidra with 'ghidra' (or '$INSTALL_DIR/ghidraRun')."
