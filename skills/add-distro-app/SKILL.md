---
name: add-distro-app
description: Add a GUI app to the chezmoi-managed ~/.sauce setup — a new init multiselect choice and an install branch in onchange_gui_apps with per-family (debian/fedora/arch/macos) package logic. Use when asked to "add a GUI app", "add a desktop app", "install steam/firefox-style app", "guiApps choice", or "package app on apply".
---

# Add a GUI app to `~/.sauce`

GUI apps are **opt-in at init** and installed by the
`run_onchange_before_40-gui-apps` chezmoiscript when the selection changes. They use
the system package manager (and sometimes vendor repos / Homebrew casks on macOS), not
`update-*.sh` or `.chezmoiexternal.toml.tmpl`. This path is for apps with **bespoke,
per-family install logic**. A plain Flathub app is simpler — use `add-tool-installer`
Path A (`flatpakCatalog` + `flatpaks` prompt) instead.

**Two sibling prompts share this shape.** *Emulators* (steam/wine/qemu) live in a
separate `$emulators` prompt → `onchange_emulators` → `run_onchange_before_38-emulators`
wrapper; the code and steps are identical to GUI apps, just a different list/function.
Add an emulator there instead of `$guiApps`. And note many `$guiApps` keys are **not**
installed here at all — the ones that ship as `update-*.sh` (`vscode`, `zed`, `qdmr`,
`cursor`, `ghidra`, `jetbrains-toolbox`, `lmstudio`, `obsidian`, `docker`, `codex`) are
installed by the run-updaters step from the GUI-apps selection (they're listed in
`$desktopTools` in `run_once_after_70-run-updaters.sh.tmpl`); those need **no** `_has`
branch here. Use this path only for apps with bespoke `install_pkgs`/cask logic.

## 1. Add the init choice

In `home/.chezmoi.toml.tmpl`, add the app key to the `$guiAppChoices` list (defined once
inside the non-Windows / non-WSL block; it's used both as the choice set and as the base
for the env-seeded default):

```gotemplate
{{- $guiAppChoices := list "firefox" "sway" "gnuradio" "qdmr" "vscode" "zed" ... "<key>" -}}
```

Each prompt's default is pre-seeded from a `SAUCE_*` env var (here `SAUCE_GUI_APPS`) —
you don't touch that logic; adding the key to `$guiAppChoices` is enough. The key is a
short lowercase identifier, stored in `[data].guiApps` and passed to the wrapper as
`GUI_APPS`.

## 2. Implement install logic

In `scripts/onchange.sh`, inside `onchange_gui_apps`, add an `_has <key>` branch.
`family` is set at the top of the function (`family="${FAMILY:-$(detect_family)}"`) and
is one of `debian` / `fedora` / `arch` / `macos`. Simplest case — same package name
everywhere (the real `gnuradio` branch):

```bash
if _has gnuradio; then
    install_pkgs gnuradio || log_warn "gnuradio install failed."
fi
```

When the package name differs per family, or install needs extra setup, `case "$family"`
(the real `firefox` branch is the template — `install_cask` on macOS, plain `install_pkgs`
on fedora/arch, a Mozilla APT repo first on debian):

```bash
if _has <app>; then
    case "$family" in
        macos)       install_cask <cask-name> || log_warn "<app> install failed." ;;
        fedora|arch) install_pkgs <name>      || log_warn "<app> install failed." ;;
        debian)      # extra repo/arch setup here, then:
                     install_pkgs <name>      || log_warn "<app> install failed." ;;
    esac
fi
```

Patterns already in `onchange_gui_apps` / `onchange_emulators` (read them for the exact
code):

- **Same package name everywhere** — one `install_pkgs`, no `case` (`gnuradio`).
- **macOS via Homebrew** — an `install_cask <cask>` `macos)` arm on every app that
  exists on mac (firefox; in `onchange_emulators`: steam, wine → `wine-stable`; qemu uses
  `install_pkgs qemu`).
- **Vendor repo first** — enable a third-party repo (Firefox → Mozilla APT; Steam →
  RPM Fusion on Fedora), then `install_pkgs`.
- **Architecture extras** — enable i386/multilib before installing (Steam & Wine on
  Debian; multilib on Arch — both in `onchange_emulators`).
- **Download + local install** — `ensure_dir "$CACHE"`, `download`, `install_local_pkg`
  (Steam `.deb` on Debian, in `onchange_emulators`).
- **Package list + companions** — install a whole list then extras (`sway` installs
  `"${sway_pkgs[@]}"` from `sway.common` plus `mako`/`mako-notifier`).
- **Post-install** — `systemctl enable`, `usermod -aG`, `log_hint` for logout (QEMU/libvirt).

Helpers live in `scripts/lib/distro.sh` (`install_pkgs`, `install_cask`,
`install_local_pkg`, `pkg_refresh`, `detect_family`) and `scripts/lib/common.sh`
(`fetch`, `download`, `ensure_dir`, `log_*`). Keep installs **idempotent** and
**best-effort** (`|| log_warn`) — `onchange` re-runs on selection changes. Linux-only
apps (e.g. `sway`) should `log_info` and skip on macOS rather than fail.

## 3. Side effects of a non-empty guiApps selection

`.desktop` (template context for desktop-only files) is derived as
`or (gt (len $emulators) 0) (or (gt (len $guiApps) 0) (gt (len $flatpaks) 0))` in
`home/.chezmoi.toml.tmpl` — so a non-empty `emulators`, `guiApps`, **or** `flatpaks`
selection turns it on. The whole desktop block (all three prompts) is skipped when
`$headless` is true or on WSL. If your app ships a
`.desktop` launcher managed elsewhere (an external, or `dot_local/share/applications/`),
gate that file on the app key in `home/.chezmoiignore` (see the `obsidian` / `lmstudio` /
`cursor` gates there).

## 4. What this path is not for

| Need | Use instead |
|---|---|
| Plain Flathub app (no bespoke logic) | `flatpakCatalog` + `flatpaks` prompt — `add-tool-installer` Path A |
| CLI tool in `~/.local/bin` | `add-tool-installer` Path B (external) |
| Self-updating / sudo vendor installer | `add-tool-installer` Path C (`update-*.sh`) |
| Optional network CLI bundle | `packages.netTools` in `.chezmoidata.yaml` + net-tools step |
| Windows GUI app | `winget.apps` + `winApps` prompt — `add-tool-installer` Path A |

`fish` as a shell is **not** a GUI app — it's in the always-installed base
(`packages.extras.common` in `.chezmoidata.yaml`, `install_pkgs fish`). The shell
*config* goes in `add-shell-fragment`.

## 5. Wrapper wiring (already exists)

`home/.chezmoiscripts/run_onchange_before_40-gui-apps.sh.tmpl` passes `FAMILY`,
`GUI_APPS`, and `SWAY_PKGS` to `bash "$HOME/.sauce/scripts/onchange.sh" gui-apps`.
You normally **only** edit `.chezmoi.toml.tmpl` and `onchange_gui_apps` — no new
chezmoiscript unless you split apps into a separate step (use `add-chezmoiscript-step`).
Note a `run_onchange_*` step re-runs only when its *rendered wrapper content* changes
(the interpolated `GUI_APPS`/`SWAY_PKGS`); editing `onchange.sh` logic alone does not
retrigger it — bump the selection or run the `onchange` alias by hand.

## After writing

Run `code-review` (data ↔ consumer: renamed keys in `.chezmoidata.yaml` / prompt lists,
`.desktop` gating) and `validate-scripts`.
