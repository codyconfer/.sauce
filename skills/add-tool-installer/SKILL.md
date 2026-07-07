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
  catalog is the name→id lookup, the prompt is what actually installs.
- **Distro desktop app** (firefox/steam/sway-style, bespoke install) → add its
  install logic to `run_onchange_before_40-distro-apps.sh.tmpl` and add its name to the
  `distroApps` `promptMultichoiceOnce` list in `home/.chezmoi.toml.tmpl`. `.desktop`
  (which gates desktop-only externals/configs) is derived from the `distroApps` and
  `flatpaks` prompt lists being non-empty.

The installers are `home/.chezmoiscripts/run_once_before_10-base-packages.sh.tmpl`,
`run_onchange_before_40-distro-apps.sh.tmpl` (repo-setup apps like firefox/steam
+ sway), and `run_onchange_before_50-flatpaks.sh.tmpl`. Distro packages / flatpaks
are then kept current by the system `update` alias — no `update-*.sh` needed.

## Path B — download-only tool (binary / tarball / AppImage into a user dir)

Add an entry to `home/.chezmoiexternal.toml.tmpl`. chezmoi downloads it and
re-fetches when `refreshPeriod` lapses. Use this when the tool is a plain download
into `~/.local/bin` or `~/.apps` (no sudo, no vendor installer). Examples:

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

# whole extracted tree (e.g. ~/.apps/<tool>/bin/...)
[".apps/<tool>"]
    type = "archive"
    url = "..."
    stripComponents = 1
    refreshPeriod = "168h"
```

Resolve a "latest" URL with the GitHub latest-download redirect
(`.../releases/latest/download/...`), or `{{ (gitHubLatestRelease "owner/repo").TagName }}`
/ ranging over `.Assets`, or `{{ output "curl" "-fsSL" "<version-url>" | trim }}`.
Gate GUI apps behind `{{ if .desktop }}`.

## Path C — sudo / vendor installer / self-updating tool

Write `scripts/update-<tool>.sh`, following the existing pattern (model after
`scripts/update-go.sh`). Use this when the tool needs `sudo`, installs into
`/usr/local`, runs a vendor `curl | sh` installer, or self-updates. These run once
at setup (via `run_once_after_70-run-updaters`) and any time after via the alias
matching the filename or `update-all`.

```bash
#! /bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_search "Fetching the latest <tool> version..."
# resolve latest, version_gate to skip when current, mktemp+trap, download,
# verify_sha256/verify_md5_etag, install under /usr/local or "$APPS".
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
  `read_stamp`/`write_stamp`, `ensure_dir`, `ensure_node`, and the `log_*` helpers.
  (It sources `config.sh` and `distro.sh`, so sourcing `common.sh` pulls in all three.)
- `scripts/lib/distro.sh` — `detect_family`, `install_pkgs`, `install_local_pkg`,
  `pkg_refresh`, `ensure_flatpak`, `install_flatpak`.
- `scripts/lib/config.sh` — tunables (`APPS`, `GO_ARCH`, `DOTNET_CHANNEL`,
  `ZSH_PLUGINS`, `GITHUB_USER`, `SAUCE_DIR`).
- `scripts/lib/runner.sh` — `run_update_scripts`/`print_summary` (with `box`/`run_step`);
  drives `scripts/update-all.sh`. You don't source this from an `update-*.sh` — it's the
  harness that runs them.

## After writing

Run the `validate-scripts` skill (chezmoi template + apply dry-run, `bash -n`,
`shellcheck`).
