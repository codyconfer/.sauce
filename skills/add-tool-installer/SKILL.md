---
name: add-tool-installer
description: Add a new tool to the chezmoi-managed ~/.sauce setup — a distro package or flatpak (.chezmoidata.yaml), a download-only binary/tarball/AppImage (.chezmoiexternal.toml.tmpl), or a sudo/vendor/self-updating installer (scripts/update-<tool>.sh). Use when asked to "add a new tool", "install <X> in setup", "add a flatpak app", or "add an update script".
---

# Add a tool to `~/.sauce`

`~/.sauce` is managed with [chezmoi](https://chezmoi.io) (source under `home/`,
selected by `.chezmoiroot`). Pick the path that matches the tool.

## Path A — distro package or flatpak (declarative)

Add the name to `home/.chezmoidata.yaml`; a `run_onchange_*` script installs it on
the next `chezmoi apply`. No script to write.

- **Base CLI package** → `packages.essential.common` (hard-fail) or
  `packages.extras.common` (best-effort). Add a per-family override list
  (`debian`/`fedora`/`arch`) when the package name differs.
- **Sway/Wayland package** → `sway.common`.
- **Flathub app** → two steps: add `<choice>: <app.id>` (e.g.
  `slack: com.slack.Slack`) to the `flatpakCatalog` map in `home/.chezmoidata.yaml`,
  then add `<choice>` to the `flatpaks` `promptMultichoiceOnce` list (both the choice
  list and the defaults) in `home/.chezmoi.toml.tmpl`. Keep the two in sync — the
  catalog is the name→id lookup, the prompt is what actually installs. On macOS the same
  `flatpaks` selection resolves through the parallel `caskCatalog` map in
  `home/.chezmoidata.yaml`, so add a `<choice>: <cask-name>` entry there too when the app
  has a Homebrew cask equivalent.
- **GUI app** (firefox/sway/gnuradio-style, bespoke install) → add its
  install logic to the `onchange_gui_apps` function in `scripts/onchange.sh` and add
  its name to the `guiApps` `promptMultichoiceOnce` list in `home/.chezmoi.toml.tmpl`
  (emulators are the sibling `$emulators` prompt → `onchange_emulators`). `.desktop`
  (which gates desktop-only externals/configs) is derived from the `emulators`, `guiApps`,
  and `flatpaks` prompt lists being non-empty, and the whole desktop layer is skipped when
  `$headless` is true. See `add-distro-app` for the full pattern.
- **Windows GUI app** (native Windows only) → add its winget id to `winget.apps` in
  `home/.chezmoidata.yaml` and add the choice to the `winApps` `promptMultichoiceOnce`
  list in `home/.chezmoi.toml.tmpl`.
- **Windows CLI/dev tool** (native Windows only) → add its winget id to `winget.tools`
  and the choice to the `winTools` prompt. `run_onchange_before_40-winget.ps1` installs
  the selection idempotently. Note the bash `update-*.sh` layer is POSIX-only
  (Linux + macOS) and does not run on native Windows — winget is the only path there.

The install *logic* lives in `scripts/setup.sh` (run-once steps: `base-packages`,
`github-auth`, ...) and `scripts/onchange.sh` (re-runnable steps: `gui-apps`,
`flatpaks`, `nvim-bootstrap`). The `home/.chezmoiscripts/run_{once,onchange}_*` files are
thin wrappers that pass the selection as env vars and call a subcommand. A
`run_onchange_*` step re-runs only when its *rendered wrapper content* changes (the
interpolated data — FAMILY, GUI_APPS, FLATPAK_IDS, …); editing `onchange.sh` logic
alone does **not** retrigger it, so to force a re-run bump the selection/data or just run
the `onchange` alias by hand. Both scripts are also exposed as the `setup`/`onchange`
aliases (they fall back to `chezmoi data` when run by hand). Distro packages / flatpaks
are then kept current by the system `update` alias — no `update-*.sh` needed.

## Path B — download-only tool (binary / tarball / AppImage into a user dir)

Add an entry to `home/.chezmoiexternal.toml.tmpl`. chezmoi downloads it and
re-fetches when `refreshPeriod` lapses. Use this when the tool is a plain download
into `~/.local/bin` or `~/.local/opt` (no sudo, no vendor installer). Examples:

```toml
# single binary
[".local/bin/<tool>"]
    type = "file"
    url = "https://github.com/<owner>/<repo>/releases/latest/download/<asset>"
    executable = true
    refreshPeriod = "168h"

# one binary out of a release tarball
[".local/bin/<tool>"]
    type = "archive-file"
    url = "https://github.com/<owner>/<repo>/releases/latest/download/<asset>.tar.gz"
    path = "<file-inside-archive>"
    executable = true
    refreshPeriod = "168h"

# whole extracted tree (e.g. ~/.local/opt/<tool>/bin/...)
[".local/opt/<tool>"]
    type = "archive"
    url = "..."
    stripComponents = 1
    refreshPeriod = "168h"
```

Resolve a "latest" URL with the GitHub latest-download redirect
(`.../releases/latest/download/...`), or `{{ (gitHubLatestRelease "owner/repo").TagName }}`
/ ranging over `.Assets`, or `{{ output "curl" "-fsSL" "<version-url>" | trim }}`.
Gate GUI apps behind `{{ if .desktop }}`.

Then make the tool opt-in-able: wrap its table in
`{{- if has "<key>" (index . "tools" | default (list)) }} … {{- end }}` (put any per-tool
`output`/version lookup *inside* the `if` so it's skipped when deselected) and add
`<key>` to the `$toolChoices` list in `home/.chezmoi.toml.tmpl` (used as both the
choices and the defaults). The `<key>` is the external's table key.

## Path C — sudo / vendor installer / self-updating tool

Write `scripts/update-<tool>.sh`, following the existing pattern (model after
`scripts/update-go.sh`). Use this when the tool needs `sudo`, installs into
`/usr/local`, runs a vendor `curl | sh` installer, or self-updates. These run once
at setup (via `run_once_after_70-run-updaters`) and any time after via the alias
matching the filename or `update-all`.

Then add `<tool>` (the `update-<tool>.sh` suffix) to the `$toolChoices` list in
`home/.chezmoi.toml.tmpl` — `run_update_scripts` (`scripts/lib/runner.sh`) only runs
an `update-*.sh` whose suffix is in that `tools` selection. If the tool drops a GUI
`.desktop` launcher, also gate the launcher on its key in `home/.chezmoiignore`
(see cursor/obsidian/lmstudio).

**macOS:** if the installer is Linux-specific (hardcoded `linux`/`amd64` URLs, `/usr/local`,
AppImage, apt/dnf/pacman), add a darwin guard right after sourcing `common.sh`:

```bash
if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi
```

and add the tool → Homebrew mapping (`formula <name>` or `cask <name>`) to `_brew_spec`
in `scripts/lib/distro.sh`. If the installer is already cross-platform (a vendor
`curl | sh`, `npm -g`, `go install`, git clone), no guard is needed — it runs as-is on
both OSes. Prefer a real cross-platform installer over the brew mapping when one exists.

```bash
#! /bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEST="$BIN/<tool>"

cleanup() {
    log_clean "Removing <tool>..."
    remove_paths "$DEST"
    log_done "<tool> removed."
}
dispatch_remove "$@"

log_search "Fetching the latest <tool> version..."
# resolve latest, version_gate to skip when current, mktemp+trap, download,
# verify_sha256/verify_md5_etag, install under /usr/local, "$OPT", or "$BIN".
log_done
```

## PATH / env

If the tool needs PATH or env, add a **runtime-guarded** block (a no-op when the
tool is absent) to all three rc files: `home/dot_zshrc`, `home/dot_bashrc`
(POSIX, e.g. `[ -d "$DIR" ] && export PATH=...`), and
`home/dot_config/fish/config.fish` (fish, e.g. `test -d "$DIR"; and fish_add_path ...`).
Put it in the "tooling env/PATH" section. There is no longer a profile builder or
`profile.d` — the block lives directly in the rc file.

## Reusable bash helpers (Path C)

- `scripts/lib/common.sh` — `fetch`, `download`, `download_with_headers`,
  `verify_sha256`, `verify_md5_etag`, `version_current`/`version_gate`,
  `read_stamp`/`write_stamp`, `ensure_dir`, `ensure_node`, `extract_appimage_icon`
  (pull an AppImage's `.DirIcon` into `~/.local/share/icons/<name>.png`), the `log_*` helpers,
  and the removal helpers `remove_paths`/`remove_sudo_paths`/`remove_cmd`/`remove_stamp` +
  `dispatch_remove` (used by each script's `cleanup()` — see the Path C template).
  (It sources `config.sh` and `distro.sh`, so sourcing `common.sh` pulls in all three.)
- `scripts/lib/distro.sh` — `detect_family`, `install_pkgs`/`remove_pkgs`, `install_local_pkg`,
  `pkg_refresh`, `ensure_flatpak`, `install_flatpak`/`remove_flatpak`.
- `scripts/lib/config.sh` — tunables (`OPT`, `BIN`, `ICONS`, `CACHE`, `GO_ARCH`,
  `DOTNET_CHANNEL`, `ZSH_PLUGINS`, `SAUCE_DIR`).
- `scripts/lib/runner.sh` — `run_update_scripts`/`print_summary` (with `box`/`run_step`);
  drives `scripts/update-all.sh`. You don't source this from an `update-*.sh` — it's the
  harness that runs them.

## After writing

Run the `validate-scripts` skill (chezmoi template + apply dry-run, `bash -n`,
`shellcheck`). If the change touched PowerShell/winget files (`bootstrap.ps1`, a
`*.ps1.tmpl`, the PS profile), it also renders and parses those.
