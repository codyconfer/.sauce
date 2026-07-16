---
name: add-chezmoiscript-step
description: Add a new chezmoi run script step to the ~/.sauce setup — a run_once or run_onchange wrapper under home/.chezmoiscripts/ and a matching arm in scripts/setup.sh or scripts/onchange.sh. Use when asked to "add a bootstrap step", "new run script", "run on apply", or "chezmoiscripts".
---

# Add a chezmoiscript step to `~/.sauce`

chezmoi runs scripts in `home/.chezmoiscripts/` during `chezmoi apply`. Each one is a
**thin wrapper** that passes selection/env vars and calls `scripts/setup.sh <step>` (run
once) or `scripts/onchange.sh <step>` (re-runnable). The real logic lives in those two
dispatchers.

## 1. Choose when it runs

Name the wrapper file so chezmoi orders it correctly:

| Prefix | Runs |
|---|---|
| `run_once_before_NN-*` | Once, before managed files are written |
| `run_onchange_before_NN-*` | On every apply when its **rendered content hash** changes (selection/data) |
| `run_once_after_NN-*` | Once, after files are written |
| `run_onchange_after_NN-*` | After files, re-runs when its rendered content changes |

Pick `NN` relative to the existing scripts. Current numbering:

| Wrapper | Dispatcher call |
|---|---|
| `run_once_before_10-base-packages` | `setup.sh base-packages` |
| `run_once_before_20-github-auth` | `setup.sh github-auth` |
| `run_once_before_30-oh-my-posh` | `setup.sh oh-my-posh` |
| `run_onchange_before_38-emulators` | `onchange.sh emulators` |
| `run_onchange_before_40-gui-apps` | `onchange.sh gui-apps` |
| `run_onchange_before_40-winget.ps1` | (Windows-only PowerShell, no bash dispatcher) |
| `run_onchange_before_45-net-tools` | `onchange.sh net-tools` |
| `run_onchange_before_50-flatpaks` | `onchange.sh flatpaks` |
| `run_once_after_70-run-updaters` | `setup.sh run-updaters` |
| `run_onchange_after_80-nvim-bootstrap` | `onchange.sh nvim-bootstrap` |
| `run_once_after_90-chsh-zsh` | `setup.sh chsh-zsh` |
| `run_once_after_95-tailscale` | `setup.sh tailscale` |

Lower `NN` runs first within the same prefix group.

## 2. Write the wrapper

Create `home/.chezmoiscripts/<name>.sh.tmpl` (use `.sh` without `.tmpl` only if it needs
no chezmoi data — see `run_once_before_30-oh-my-posh.sh`):

```bash
#!/usr/bin/env bash

set -uo pipefail
MY_FLAG="{{ .someField }}" \
FAMILY="{{ .family }}" \
    bash "$HOME/.sauce/scripts/onchange.sh" my-step
```

Patterns to follow (see `run_onchange_before_40-gui-apps.sh.tmpl` for the real thing):

- Always `set -uo pipefail`.
- Pass chezmoi data as **env vars** (uppercase); the dispatcher reads them with
  `${VAR:-}` fallbacks or its `_data '.field'` helper.
- Call `bash "$HOME/.sauce/scripts/setup.sh" …` or `onchange.sh` — never inline install
  logic in the wrapper. (`~/.sauce` is the fixed source dir; there is no `.repoDir` data
  key.)
- Gate optional / OS-specific steps with template `{{- if … }}` (see
  `run_onchange_before_50-flatpaks.sh.tmpl`, which branches darwin → `FLATPAK_CASKS`
  vs `FLATPAK_IDS`).

## 3. Add the dispatcher arm

In `scripts/setup.sh` (run-once) or `scripts/onchange.sh` (re-runnable), add a function
and a `case` arm — and add it to the `all)` arm too if it should run in a full pass:

```bash
setup_my_step() {
    # idempotent install/config logic
    log_done "my-step complete."
}

case "${1:-all}" in
    my-step)  setup_my_step ;;
    …
    all)
        …
        setup_my_step
        ;;
    *) log_error "unknown setup step: ${1:-}"; exit 2 ;;
esac
```

Rules:

- **Step name** in the wrapper's last argument must match the `case` arm exactly.
- A wrapper without a matching arm makes `chezmoi apply` exit non-zero (`unknown … step`).
- A `case` arm without a wrapper is dead code — remove it or add a wrapper.
- Reuse helpers from `scripts/lib/common.sh` (`log_*`, `fetch`, `download`, …),
  `scripts/lib/distro.sh` (`install_pkgs`, `detect_family`, …). Both dispatchers already
  source `common.sh` and define `_data`.

`run_once_*` steps should be idempotent (safe to run once per machine).
`run_onchange_*` steps re-run when the *rendered wrapper content* changes — keep them
re-runnable (install/update, not destructive without intent). Editing dispatcher logic
alone does **not** retrigger an onchange step; bump the interpolated data or run the
`setup`/`onchange` alias by hand.

## 4. Wire init prompts (user choices *and* org/machine constants)

Anything that differs per user, org, or machine must be **configurable**, not a literal
in the dispatcher — `~/.sauce` is a template meant to be forked. That covers user toggles
(install X?) and org/machine constants (repo URL, project, cluster name, email domain,
absolute path).

1. Add a prompt in `home/.chezmoi.toml.tmpl` (`promptBoolOnce`, `promptMultichoiceOnce`,
   `promptStringOnce`, …) — for a constant, use today's value as the **default** so
   behavior is unchanged out of the box.
2. Expose the answer under `[data]` in the same file.
3. Pass it into the wrapper as an env var and/or resolve it in the dispatcher with the
   **env → `_data` → default** pattern already used here (e.g. `setup_tailscale`):

   ```bash
   on="${TAILSCALE:-$(_data '.tailscale')}"
   [ "$on" = true ] || { log_info "…skipping."; return 0; }
   ```

   `base-packages` shows the list form (`${ESSENTIAL:-}` else
   `mapfile … < <(_data '.packages.essential…')`).

Never leave an org/machine-specific literal inline — `code-review` §3 flags it.

For distro-app-style multiselects, see `add-distro-app`. For tool installers, see
`add-tool-installer`.

## 5. Running it by hand

Scripts under `scripts/*.sh` (except `functions.sh`) are auto-aliased by the rc files, so
the dispatcher is runnable as `setup my-step` / `onchange my-step` after the next shell.
You can also call it directly:

```bash
bash ~/.sauce/scripts/setup.sh my-step
```

No extra alias wiring needed.

## After writing

Run `code-review` (chezmoiscript ↔ dispatcher wiring is an invariant) and
`validate-scripts`.
