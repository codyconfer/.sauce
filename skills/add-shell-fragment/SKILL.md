---
name: add-shell-fragment
description: Add or edit shell config in the chezmoi-managed ~/.sauce setup — an alias/function/env/PATH change across the monolithic zsh/bash/fish rc files, shared helpers in scripts/functions.sh, and cross-shell parity. Use when asked to "add an alias", "new zsh/bash/fish config", "add to PATH", "shell function", or "shell rc change".
---

# Add shell config to `~/.sauce`

`~/.sauce` uses **monolithic rc files**, not `conf.d/` fragments and no profile gating.
There are three managed rc files:

- `home/dot_zshrc` — zsh (the login shell)
- `home/dot_bashrc` — bash
- `home/dot_config/fish/config.fish` — fish

They are **plain files, not templates** (no `.tmpl`, no chezmoi data). Shared bash/zsh
logic is factored into `scripts/functions.sh`, which both `dot_zshrc` and `dot_bashrc`
source; **fish does not source it** (it is bash-only) and reimplements the equivalents
natively in `config.fish`. Edit the source files in the repo and `chezmoi apply` — never
edit the deployed `~/.zshrc` etc. directly.

## Where each kind of change goes

| Change | Where |
|---|---|
| Alias/function shared by **bash + zsh** | `scripts/functions.sh` (sourced by both) |
| The same behavior in **fish** | reimplement natively in `config.fish` |
| PATH / tool env var | the **"tooling env/PATH"** block of each rc file |
| Alias for a `scripts/*.sh` | **nothing** — auto-generated (see below) |
| Personal, machine-local tweak | `~/.zshrc.local` / `~/.bashrc.local` / `~/.config/fish/user.fish` |

### Shared aliases & functions → `scripts/functions.sh`

`scripts/functions.sh` holds the cross-shell interactive helpers (`update`,
`docker-containers`/`LIST_DOCKER_CONTAINERS`, `get_secret`, the color vars, the
`_sauce_print_header` banner, and the `sauce`/`sauce-edit`/`sauce-cd` aliases). It is
bash & zsh compatible and intentionally self-contained — it runs in **every** interactive
shell, so it does **not** `source lib/common.sh`. Add shared bash/zsh aliases/functions
here. Then add the fish equivalent to `config.fish` (its `update` function and `docker`
block already mirror this file).

### PATH / env → the "tooling env/PATH" block

Each rc file has a `# tooling env/PATH` section with **one runtime-guarded block per
tool** (a no-op when the tool dir is absent). Add a matching block to all three:

- bash/zsh: `[ -d "$DIR" ] && export PATH="$DIR:$PATH"`
- fish: `test -d "$DIR"; and fish_add_path "$DIR"` (use `-a` to append, matching Go/dotnet)

Follow the existing entries (dotnet, gcloud, Go, lmstudio, nvm, opencode, pyenv) — put
the tool's block in the same section in each file, and note nvm's `nvm.sh` is bash/zsh
only (fish just sets `NVM_DIR`). If a tool's install dir must be on `PATH`, this is the
only place it gets wired — there is no `05-env` fragment and no `profile.d`.

### Script aliases are automatic

Both `dot_zshrc` and `config.fish` (and `dot_bashrc`) contain a loop that aliases every
`~/.sauce/scripts/*.sh` (except `functions.sh`) to `bash <script>`. So adding
`scripts/update-foo.sh` or a new dispatcher subcommand gets a `update-foo` / `setup` /
`onchange` alias for free — no rc edit needed. (See `add-tool-installer`,
`add-chezmoiscript-step`.)

### Personal tweaks are not managed

`~/.zshrc.local`, `~/.bashrc.local`, and `~/.config/fish/user.fish` are created once
(via the `create_*` sources) and **never touched by chezmoi** again. User-specific config
goes there, sourced at the end of each rc file — not into the managed rc files.

## Needs chezmoi data?

The rc files are plain, so they can't use `{{ .foo }}`. If a change genuinely needs init
data, rename the source to add `.tmpl` (e.g. `dot_zshrc.tmpl`) and render with
`chezmoi execute-template` when validating. Prefer a runtime guard over templating when
possible — it keeps the file a plain, forkable script.

## Cross-shell parity

When adding behavior to one shell, mirror it in the others (expressed in each shell's
syntax):

| Concern | bash / zsh | fish |
|---|---|---|
| Aliases | `alias foo='bar'` | `alias foo 'bar'` |
| Functions | `foo() { … }` | `function foo … end` |
| PATH | `[ -d … ] && export PATH=…` | `fish_add_path …` |
| Shared helpers | `scripts/functions.sh` (sourced) | reimplemented inline in `config.fish` |

## What not to do

- Do not create `conf.d/` fragments or a profile loader — `~/.sauce` has neither.
- Do not put personal config in the managed rc files — use the `*.local` / `user.fish`
  files.
- Do not add a PATH block for a tool without checking its install dir matches an
  `update-*.sh` or external entry (`add-tool-installer`).

## After writing

Run `code-review` if you touched PATH/env or cross-shell behavior (parity check across
the three rc files + `functions.sh`), then `validate-scripts` (syntax-check the rendered
rc files and `config.fish`).
