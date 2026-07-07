---
name: add-tool-installer
description: Scaffold a new scripts/update-<tool>.sh (self-updating tool) or scripts/install-<tool>.sh (install-once distro pkg / flatpak) installer for the ~/.sauce bootstrap toolkit, following the established fetch -> verify -> install -> register pattern. Use when asked to "add a new tool", "add an update script", "install <X> in setup", or "add a flatpak app".
---

# Add a tool installer to `~/.sauce`

Every installable tool in this repo has its own idempotent, re-runnable script in
`scripts/`. The shell auto-generates an alias matching the filename, and
`scripts/setup.sh` runs them all, so **no manual wiring is needed** — just drop the
file in `scripts/`.

The filename prefix encodes *who updates the tool*:

- **`update-<tool>.sh`** — the script fetches/reinstalls the latest version on every
  run (downloads, `npm`/`pipx`/`go install`, vendor install scripts). Run by both
  `setup.sh` and `update-all.sh`. Use this for Variant A below.
- **`install-<tool>.sh`** — a one-time install into a package manager that then keeps
  the tool current: a distro package (`install_pkgs`) or a Flatpak (`install_flatpak`).
  Run by `setup.sh` only (**not** `update-all.sh`); the `update` alias (`apt upgrade`
  / `pacman -Syu` / `dnf upgrade` + `flatpak update`) handles updates. Use this for
  Variant B below.

Pick the variant that matches the tool.

## Variant A — downloaded tool (binary/tarball with a checksum)

Model after `scripts/update-go.sh`. Structure:

```bash
#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_search "Fetching the latest <tool> version..."
# fetch release metadata (GitHub API, vendor JSON, etc.) and parse with jq
RELEASE_JSON=$(fetch "https://.../releases/latest")
LATEST_VERSION=$(echo "$RELEASE_JSON" | jq -r '.tag_name')
# ...guard: exit 1 with log_error if version is empty/null...

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading ..."
download "$DOWNLOAD_URL" "$TMPDIR/$ASSET"
verify_sha256 "$EXPECTED_SHA" "$TMPDIR/$ASSET"   # or verify_md5_etag when no sha is published

log_install "Installing..."
# extract/install under /usr/local (system) or "$APPS" (~/.apps, per-user)

profile_register <tool> <<'EOF'
# <tool>
export PATH="$PATH:/usr/local/<tool>/bin"
EOF

log_done
<tool> --version
log_hint "Restart your terminal or run 'source ~/.zshrc' to update your PATH."
```

Notes:
- Always `set -euo pipefail`, always source `lib/common.sh` first.
- Prefer verifying a published checksum. Use a `mktemp -d` + `trap ... EXIT` for
  cleanup.
- Only register a profile block if the tool needs PATH/env changes. If it also
  needs a fish-specific block, add `profile_register_fish <tool> <<'EOF' ... EOF`.
- AppImages/binaries dropped in `$APPS` don't get an app-menu launcher
  automatically (only Flatpaks/distro packages do). If the tool is a GUI app,
  add one with `install_desktop_entry` — see `scripts/update-obsidian.sh`:
  ```bash
  APP_NAME="<App>" APP_COMMENT="<desc>" APP_EXEC="$PKGPATH" \
  APP_ICON="<icon-name-or-file>" APP_CATEGORIES="Utility;" \
  install_desktop_entry <tool>
  ```

## Variant B — flatpak desktop app or distro package (name it `install-<tool>.sh`)

Model after `scripts/install-zen.sh` — usually one line:

```bash
#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

install_flatpak <app.id.here>

log_done
log_hint "Launch <App> from your app menu, or run: flatpak run <app.id.here>"
```

For a native distro package instead of a flatpak, use `install_pkgs <pkg>` (see
`scripts/install-fish.sh`); add distro-specific repo setup inline only when needed
(see `scripts/install-firefox.sh`, `scripts/install-steam.sh`).

## Reusable helpers (don't reinvent these)

- `scripts/lib/common.sh` — `fetch <url>`, `download <url> <dest>`,
  `verify_sha256 <sha> <file>`, `verify_md5_etag`, `ensure_dir`, and the
  `log_*` helpers (`log_search`, `log_found`, `log_download`, `log_install`,
  `log_done`, `log_hint`, `log_error`, `log_info`, `log_link`).
- `scripts/lib/distro.sh` — `install_pkgs <pkgs...>` (apt/dnf/pacman aware),
  `install_flatpak <app-id>`, `install_local_pkg <file>`, `pkg_refresh`.
- `scripts/lib/profile.sh` — `profile_register <tool>` (POSIX block shared by
  bash + zsh, rebuilds both) and `profile_register_fish <tool>`.
- `scripts/lib/desktop.sh` — `install_desktop_entry <id>` renders a `.desktop`
  launcher (KDE/GNOME) into `$DESKTOP_DIR` from the `APP_NAME` / `APP_EXEC` /
  `APP_ICON` / `APP_COMMENT` / `APP_CATEGORIES` env vars. Idempotent.
- `scripts/lib/config.sh` — tunables such as `APPS` (~/.apps), `GO_ARCH`,
  `DOTNET_CHANNEL`, `SAUCE_DIR`, `GITHUB_USER`. Read/extend here rather than
  hardcoding.

## Correctness: use the current profile API

Register profile blocks with **`profile_register`** / **`profile_register_fish`**.
Some existing scripts still call the removed names `zshrc_register` (and
`setup.sh` calls `zshrc_build`) — that is a stale-rename bug that fails at
runtime with "command not found". Do not copy it into new scripts.

## After writing

Run the `validate-scripts` skill (or at least `bash -n scripts/<update|install>-<tool>.sh`)
to catch syntax errors before committing.
