---
name: code-review
description: Review a change to the chezmoi-managed ~/.sauce setup — sweep for references orphaned by deleted/renamed files, verify the framework wiring invariants (chezmoiscript ↔ dispatcher, tools prompt ↔ installer, flatpak/winget prompt ↔ catalog, PATH ↔ install dirs, cross-shell parity), and confirm comments/docs still match. Use when asked to "review my changes", "review this diff", "check the dotfiles change", or "did the refactor leave anything dangling".
---

# Review a change to `~/.sauce`

`~/.sauce` is a chezmoi engine (source under `home/`, selected by `.chezmoiroot`) whose
pieces are wired together by convention, not imports — so the common defects are *broken
wiring* and *stale references left by moved/deleted files*, not logic bugs. Work through
these in order; each is a fast, mostly-grep check. Report findings, then hand off to
`validate-scripts` for the mechanical render/syntax pass.

## 1. Scope the diff

```bash
git status --short
git diff HEAD -- .          # staged + unstaged
```

List the **deleted and renamed** paths explicitly — they drive step 2. Note new
`scripts/update-*.sh`, changed rc files (`dot_zshrc` / `dot_bashrc` / `config.fish` /
`functions.sh`), `.chezmoiscripts/` added or removed, and edits to the data files
(`.chezmoidata.yaml`, `.chezmoi.toml.tmpl`).

## 2. Orphan sweep (deleted/renamed files)

For every basename that was deleted or moved, grep the whole repo — comments, docs, and
templates all count, not just code:

```bash
for name in config.fish functions.sh base-packages oh-my-posh <other-removed-names>; do
  echo "== $name =="; grep -rn "$name" . --include='*.sh' --include='*.fish' \
    --include='*.tmpl' --include='*.md' --include='*.toml' --include='*.yaml' \
    --include='*.ps1'
done
```

Any hit pointing at something that no longer exists (or now lives elsewhere) is an
orphan — fix the reference, don't just delete the mention. `README.md` and
`skills/*/SKILL.md` are the usual stragglers.

## 3. Framework wiring invariants

The glue only works if these line up — check each:

- **chezmoiscript ↔ dispatcher.** Every `home/.chezmoiscripts/run_*.sh*` wrapper calls
  `scripts/setup.sh <step>` or `scripts/onchange.sh <step>`; that `<step>` must have a
  matching arm in the dispatcher's `case`. Current steps: setup → `base-packages`,
  `github-auth`, `oh-my-posh`, `run-updaters`, `chsh-zsh`, `tailscale`; onchange →
  `distro-apps`, `flatpaks`, `net-tools`, `nvim-bootstrap`. A removed arm with a
  surviving wrapper makes `chezmoi apply` exit non-zero (`unknown … step`); a step added
  to a dispatcher should also be added to its `all)` arm.
- **tools prompt ↔ installer.** Every key in `$toolChoices`
  (`home/.chezmoi.toml.tmpl`) resolves to *exactly one* install path: a
  `scripts/update-<key>.sh` **or** a `.chezmoiexternal.toml.tmpl` table gated on
  `has "<key>" $tools`. No `update-*.sh` without a matching choice, and no choice without
  an installer.
- **flatpak prompt ↔ catalogs.** Every key in the `$flatpaks` prompt must have an entry
  in `flatpakCatalog` (Linux → Flathub id) in `.chezmoidata.yaml`; a key missing there
  renders an empty id and silently installs nothing. If the app has a macOS equivalent,
  it also needs a `caskCatalog` entry (the darwin branch of
  `run_onchange_before_50-flatpaks.sh.tmpl` reads `caskCatalog`; a missing entry just
  skips it on mac).
- **distroApps / winget prompt ↔ consumer.** Every `$distroApps` key needs an `_has`
  branch in `onchange_distro_apps`. Every `winApps` / `winTools` key needs an id under
  `winget.apps` / `winget.tools` in `.chezmoidata.yaml` (consumed by
  `run_onchange_before_40-winget.ps1`).
- **data ↔ consumers.** Lists in `.chezmoidata.yaml` (`packages.essential`,
  `packages.extras`, `packages.netTools`, `sway.common`) are read by `scripts/setup.sh` /
  `scripts/onchange.sh` via `_data`; a renamed key silently yields an empty install.
- **.desktop launcher gating.** GUI `.desktop` files under
  `dot_local/share/applications/` are gated in `home/.chezmoiignore` on `tools`
  membership (obsidian, lmstudio, cursor). A new GUI tool that ships a launcher needs a
  matching ignore stanza, or it deploys for everyone.
- **no hardcoded org/user/machine-specific values.** `~/.sauce` is a template meant to be
  forked — a script must not bake in emails, org domains, cluster names, repo URLs, or
  absolute user paths (beyond the fixed `$HOME/.sauce` source dir). Such values belong in
  an init prompt (`.chezmoi.toml.tmpl`) or `.chezmoidata.yaml`, read via the
  **env → `_data` → default** pattern (see `setup_tailscale`:
  `on="${TAILSCALE:-$(_data '.tailscale')}"`). Grep for likely offenders:
  ```bash
  grep -rn '@[a-z0-9.-]*\.\(com\|net\|org\|io\)\|git@github\|https\?://github\.com/\|/home/[a-z]' \
    scripts/ home/ --include='*.sh' --include='*.tmpl'
  ```

## 4. PATH / install-dir coverage

Every tool installs into a dir that must be on `PATH` via the **"tooling env/PATH"**
block of each rc file (there is no `conf.d`/`profile.d` — PATH lives directly in
`dot_zshrc`, `dot_bashrc`, and `config.fish`):

```bash
grep -n 'local/bin\|go/bin\|fish_add_path\|\.local/opt\|export PATH' \
  home/dot_zshrc home/dot_bashrc home/dot_config/fish/config.fish
```

If an installer drops a binary somewhere no rc block adds to `PATH`, the tool installs
but won't run — flag it. Blocks must be runtime-guarded (`[ -d … ]` / `test -d …`) so
they no-op when the tool is absent.

## 5. Cross-shell parity

The three rc files plus `scripts/functions.sh` must stay in sync — same aliases, same
`update` behavior, same PATH dirs — expressed in each shell's syntax. bash & zsh share
`functions.sh` (sourced); **fish reimplements the equivalents natively in `config.fish`**
(it does not source `functions.sh`). So a change to `functions.sh` usually needs a
mirrored change in `config.fish`, and a PATH/env change needs to land in all three rc
files.

```bash
diff <(sed -n '/tooling env.PATH/,/^# path/p' home/dot_zshrc) \
     <(sed -n '/tooling env.PATH/,/^# path/p' home/dot_bashrc)
```

A change to one shell that isn't mirrored in the others is the usual miss.

## 6. Comment / doc accuracy

Read the header comment of each changed `scripts/*.sh` and the relevant `README.md`
section against the new behavior. The refactor pattern here is that logic moves but the
prose describing it lags — reword rather than delete.

## 7. Render & syntax

Hand off to the `validate-scripts` skill (render every `*.tmpl`, dry-run `chezmoi apply`,
`bash -n` / `shellcheck` the shell files, `fish --no-execute` the fish config, and — if
`pwsh` is available — parse the PowerShell files `bootstrap.ps1`, the winget `*.ps1.tmpl`,
and the PS profile).

## Reporting

Group findings by severity: **breaks apply** (wiring/template errors) first, then
**functional** (PATH/install gaps, empty catalog lookups) then **stale comments/docs**.
For each, give the `file:line` and the one-line fix. If a check found nothing, say so —
don't imply you ran a check you skipped (e.g. shellcheck or pwsh when they aren't
installed).
