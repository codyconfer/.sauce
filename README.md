# .sauce

Linux dotfiles + machine setup (Debian, Fedora, and Arch families), managed with
[chezmoi](https://chezmoi.io).

## Quick start

One command bootstraps a fresh machine — installs chezmoi, clones this repo to
`~/.sauce`, and applies everything:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/codyconfer/.sauce/main/bootstrap.sh)
```

Already have the repo cloned? Just run `bash ~/.sauce/bootstrap.sh`, or if chezmoi
is installed, `chezmoi init --source=~/.sauce --apply`.

`chezmoi apply` (aliased to `sauce`) is safe to re-run — it installs base packages,
authenticates GitHub, installs oh-my-posh, deploys all config files, installs the
declared apps/flatpaks, downloads the CLI tools, runs the self-updating tool
installers once, bootstraps Neovim, and sets zsh as your login shell. Each step is
idempotent.

On first `init` you pick from three
multi-select lists — which distro desktop apps (Firefox, Steam, Sway, fish, Wine, QEMU),
which flatpaks (Slack, Discord, Signal, EasyEffects, OBS, Bitwarden, Zen), and which
dev tools (go, docker, gcloud, cursor, k9s, kubectl, … — every `update-*.sh` and
download-only external) to install — and whether to bring up Tailscale. Everything
defaults to selected, so accepting the defaults installs the full set. Answers are
saved to `~/.config/chezmoi/chezmoi.toml`; re-run `chezmoi init` to change the
selections.

> **Upgrading an existing install:** the dev-tools prompt (`tools`) is new. Because
> it only prompts once, run `chezmoi init` (accept the defaults) after pulling this
> change so the selection is recorded — otherwise a bare `chezmoi apply` treats it as
> "none selected" and skips the externals/launchers.

## How it's organized

chezmoi's source lives under `home/` (selected by `.chezmoiroot`), so the repo's
own directories aren't mistaken for things to deploy.

```
~/.sauce/                             # git repo + chezmoi sourceDir
  bootstrap.sh                        # install chezmoi + clone + init --apply
  .chezmoiroot                        # "home" — the source root
  home/
    .chezmoi.toml.tmpl                # generates ~/.config/chezmoi/chezmoi.toml (family, prompts)
    .chezmoidata.yaml                 # package lists (essential/extras, sway, flatpaks)
    .chezmoiexternal.toml.tmpl        # download-only tools (none currently; see skills/add-tool-installer Path B)
    .chezmoiignore                    # per-OS / per-flag exclusions
    dot_zshrc  dot_bashrc             # → ~/.zshrc, ~/.bashrc
    dot_config/
      fish/config.fish                # → ~/.config/fish/config.fish
      oh-my-posh/sauce.toml           # → ~/.config/oh-my-posh/sauce.toml (prompt theme)
      nvim/**                         # → ~/.config/nvim (lazy.nvim setup)
      nvim/lua/sauce/generated.lua.tmpl  # LSP/parser list, detected via lookPath
      sway/ waybar/ wofi/ mako/       # → ~/.config/* (tracked WM config)
    create_dot_zshrc.local            # → ~/.zshrc.local (created once, never overwritten)
    create_dot_bashrc.local           #    "  ~/.bashrc.local
    create_dot_config/fish/user.fish  #    "  ~/.config/fish/user.fish
    dot_local/share/applications/     # AppImage .desktop launchers (obsidian)
    .chezmoiscripts/                  # ordered run scripts (see below)
  scripts/
    lib/{config,common,distro,runner}.sh   # shared bash helpers
    update-*.sh                        # self-updating tools that need sudo / vendor installers
    update-all.sh                      # run every update-*.sh
  skills/                              # authoring conventions (add-tool-installer, validate-scripts)
```

### The `.chezmoiscripts/` run scripts

chezmoi runs these in name order — `before_` scripts before any files are
written, `after_` scripts once everything is in place:

| script | replaces | when |
|---|---|---|
| `run_once_before_10-base-packages` | `install-base.sh` | once |
| `run_once_before_20-github-auth` | `setup.sh` github step | once |
| `run_once_before_30-oh-my-posh` | `setup.sh` oh-my-posh step | once |
| `run_onchange_before_40-distro-apps` | firefox/steam/sway/fish/wine/qemu installers | on change |
| `run_onchange_before_50-flatpaks` | flatpak `install-*.sh` | on change |
| `run_once_after_70-run-updaters` | `setup.sh` update loop | once |
| `run_onchange_after_80-nvim-bootstrap` | `build-nvim.sh` sync tail | on lockfile/toolchain change |
| `run_once_after_90-chsh-zsh` | `setup.sh` chsh | once |
| `run_once_after_95-tailscale` | `setup.sh` tailscale | once (opt-in) |

`run_once_*` run a single time (keyed on content hash); `run_onchange_*` re-run
whenever their rendered content changes (e.g. you edit a package list).

## Keeping tools current

Two mechanisms, by tool type:

- **Declarative externals** (`home/.chezmoiexternal.toml.tmpl`) — tools that are
  just a downloaded binary/tarball/AppImage into a user directory. chezmoi
  re-downloads each when its `refreshPeriod` lapses, or on
  `chezmoi apply --refresh-externals`. None are currently defined; see
  `skills/add-tool-installer` (Path B) to add one.
- **`scripts/update-*.sh`** — tools that need `sudo`, install into `/usr/local`,
  run a vendor `curl | sh` installer, self-update, or are a plain binary download
  (go, dotnet, gcloud, aws, pyenv, poetry, zed, opencode, claude-code, codex, gcx,
  pi, nvm, wrangler, yarn, azure-cli, vscode, docker, jetbrains-toolbox,
  zsh-plugins, loglit, k9s, kubectl, cloudflared). Run once at setup, then any time
  via the alias matching the filename (e.g. `update-go`) or `update-all` for all of
  them.

Both mechanisms are gated by the `tools` init-prompt selection: an external is only
downloaded when its key is selected, and `run_update_scripts` only runs an
`update-*.sh` whose suffix is selected (a manual `update-all` reads the selection
from `chezmoi data`; running `update-go` by hand still works regardless).

Distro packages and flatpaks are kept current by the system: the `update` alias
runs `apt upgrade` / `pacman -Syu` / `dnf upgrade` plus `flatpak update`.

## Shell config & personal tweaks

The rc files (`~/.zshrc`, `~/.bashrc`, `~/.config/fish/config.fish`) are managed by
chezmoi — edit the source with `chezmoi edit ~/.zshrc` (aliased `sauce-edit`), or
edit in the repo and `chezmoi apply`. Each carries a runtime-guarded env/PATH block
per tool that no-ops when the tool is absent.

Your **personal** tweaks go in the `*.local` files (`~/.zshrc.local`,
`~/.bashrc.local`, `~/.config/fish/user.fish`), which each rc sources at the end.
chezmoi creates them once and never overwrites them, so they survive every apply.

Aliases: `sauce` = `chezmoi apply`, `sauce-edit` = `chezmoi edit --apply`,
`sauce-cd` = `chezmoi cd`.

## Neovim

`~/.config/nvim` is a lazy.nvim setup deployed by chezmoi. The enabled LSP servers
and treesitter parsers reflect the toolchains detected on the machine:
`generated.lua.tmpl` uses chezmoi's `lookPath` to emit servers/parsers for
whatever (`go`, `python3`, `node`, `dotnet`, `cargo`/`rustc`, `gcc`, `docker`,
`ruff`) is present, merged over the committed baseline in `lua/sauce/toolset.lua`.
The `run_onchange_after_80-nvim-bootstrap` script does the headless
`Lazy sync` / treesitter / Mason install, re-running whenever `lazy-lock.json` or
the detected toolset changes (set `SKIP_NVIM_BOOTSTRAP=1` to skip, e.g. in CI).

## Adding tools

See `skills/add-tool-installer`. In short: a distro package or flatpak goes in
`home/.chezmoidata.yaml`; a download-only tool gets a `home/.chezmoiexternal.toml.tmpl`
entry; anything needing sudo / a vendor installer becomes a `scripts/update-*.sh`.
If the tool needs PATH/env, add a guarded block to the rc files.
