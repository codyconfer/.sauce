# .sauce

Linux dotfiles + machine setup (Debian, Fedora, and Arch families).

## Quick start

Clone to `~/.sauce`, then run setup:

```bash
git clone git@github.com:codyconfer/.sauce.git ~/.sauce
bash ~/.sauce/scripts/setup.sh
```

`setup.sh` installs base packages, authenticates GitHub, installs oh-my-posh,
runs every `update-*` installer, symlinks the shell configs (`~/.zshrc`,
`~/.bashrc`, `~/.config/fish/config.fish`) into place with GNU stow, and sets zsh
as your login shell. It's safe to re-run — each step is idempotent and reports
pass/fail in a summary.

> Clone first — the scripts source shared helpers from `scripts/lib/`, so the
> old `curl … | bash` one-liner won't work.

## Layout

```
stow/           # GNU stow packages; each subdir mirrors its layout under $HOME
  zsh/.zshrc            bash/.bashrc            fish/.config/fish/config.fish
  nvim/.config/nvim/    omp/.config/oh-my-posh/sauce.toml
  zsh-plugins/.zsh/plugins.zsh
  sway|waybar|wofi|mako/.config/<name>/
configs/        # non-stow assets (desktop-entry template rendered by lib/desktop.sh)
themes/         # legacy oh-my-zsh theme (the oh-my-posh theme moved to stow/omp/)
scripts/
  setup.sh                    # full machine bootstrap
  stow.sh                     # (re)link / unlink the stow packages: stow.sh [stow|restow|unstow]
  build-nvim.sh               # detect toolchains, write generated.lua, then stow ~/.config/nvim
  reset-nvim.sh               # unstow nvim + wipe plugin/state dirs, then rebuild
  build-sway.sh               # stow sway/waybar/wofi/mako into ~/.config
  install-sway.sh             # install sway + waybar/wofi/mako/foot/grim/slurp companions
  update-all.sh               # run every update-* installer
  update-*.sh                 # self-updating tools (fetch latest each run; idempotent)
  install-*.sh                # install-once apps (distro pkgs / flatpaks) the pkg manager then maintains
  lib/                        # shared helpers: logging, downloads, distro detection, stow, profile fragments
```

## Updating tools

There are two kinds of installer, distinguished by name:

- **`update-*.sh`** — tools that fetch and (re)install their latest version on every
  run (binaries, tarballs, AppImages, `npm`/`pipx`/`go install`, vendor install
  scripts). Picked up by both `setup.sh` and `update-all.sh`. Re-run one to update it.
- **`install-*.sh`** — apps installed *once* into a package manager that then keeps
  them current: distro packages (Firefox, Steam, fish, zsh) via `apt`/`dnf`/`pacman`,
  and Flatpak/Flathub desktop apps (Zen, Slack, Discord, Signal, EasyEffects,
  Bitwarden, OBS). Run by `setup.sh` only — **not** `update-all.sh` — because the
  `update` alias (which runs `apt upgrade` / `pacman -Syu` / `dnf upgrade` and
  `flatpak update` in one go) is what updates them.

After setup every script is available as a shell alias matching its filename
(e.g. `update-go`, `install-obs`, `update-all`).

## Shell configs (stow)

The committed rc files (`stow/zsh/.zshrc`, `stow/bash/.bashrc`,
`stow/fish/.config/fish/config.fish`) are the real files — `scripts/stow.sh`
symlinks them into `$HOME` with GNU stow. Edit them in the repo; the symlink
means the change is live in the next shell. Two things that used to be spliced
into the rc file at build time are now sourced at **shell startup** instead:

1. a **tooling** section — per-tool env/PATH fragments that `update-*` scripts
   register into `~/.config/sauce/profile.d/`, so it reflects what's actually
   installed. bash and zsh share the POSIX-sh fragments (`profile.d/posix/*.sh`);
   fish has its own (`profile.d/fish/*.fish`). The rc files loop over that
   directory on startup — no rebuild needed;
2. a **user** section — your machine-local tweaks live in a gitignored
   `~/.config/sauce/user.sh` (fish: `user.fish`), sourced at the end of the rc
   file. Migrating from the old builder salvages any existing `sauce:user` region
   into this file automatically.

`scripts/stow.sh` is the entrypoint (aliased as `sauce-stow`):

- `stow.sh` / `stow.sh restow` — (re)link the packages. Run after a `git pull`.
  Pre-existing real rc files are backed up to `<path>.<timestamp>.bak` first.
- `stow.sh unstow` — remove the managed symlinks (real dirs like `~/.zsh` and
  `~/.config/fish`, and any plugin clones, are left alone).

Per-shell aliases (named for the shell — `zshrc`/`bashrc`/`fishrc`):

- `<shell>rc` — reload the current shell (`exec`).
- `<shell>rc-reset` — re-stow and reset `user.{sh,fish}` back to the placeholder.

> **fish** and **zsh-plugins** are stowed `--no-folding` so `~/.config/fish` and
> `~/.zsh` stay real directories (fish writes runtime state there; zsh plugin
> repos are cloned into `~/.zsh`). Everything else folds to a single dir symlink.

> Adding a tool block: call `profile_register <tool>` (POSIX, for bash+zsh) and
> `profile_register_fish <tool>` (fish) from an `update-*.sh` script, piping the
> block in via a heredoc. See `scripts/update-go.sh` for an example.

## Neovim

`scripts/build-nvim.sh` stows `~/.config/nvim` → `stow/nvim/.config/nvim` (a
lazy.nvim setup, folded to a single dir symlink) and provisions, out of the box:

- **git diffs** — gitsigns (gutter signs, hunk stage/reset/preview, blame) and
  diffview (`<leader>gd` opens a diff, `<leader>gh` file history);
- **syntax highlighting** — nvim-treesitter;
- **LSPs + completion** — mason + nvim-lspconfig + nvim-cmp;
- **themes** — the [goose](https://github.com/codyconfer/goose) / viewkit palettes
  ported to editor colorschemes: `default` (Munin, applied on startup),
  `solarized-dark`/`-light`, `one-dark-vivid`, `monokai`, `munin`,
  `retro-dark`/`-light`. Switch with `:colorscheme <name>` or the `<leader>ut`
  picker.

Like the shell tooling section, the enabled **LSP servers and treesitter parsers
reflect what's installed**: `build-nvim.sh` detects language toolchains
(`go`, `python3`, `node`, `dotnet`, `cargo`/`rustc`, `gcc`, `docker`, `ruff`) and
writes `stow/nvim/.config/nvim/lua/sauce/generated.lua` (gitignored; lands back
in the repo through the fold symlink). A committed baseline
in `lua/sauce/toolset.lua` always covers the config formats you edit (lua, bash,
json, yaml, toml, markdown, git), so the config still loads on a fresh clone. It
also registers `EDITOR`/`VISUAL=nvim` and `vi`/`vim` aliases.

Two aliases manage it:

- `nvimrc` — re-detect toolchains, re-stow the config, and sync plugins/servers.
- `nvimrc-reset` — unstow the config and wipe Neovim's plugin/state/cache dirs
  (backed up to `*.bak`), then rebuild from scratch.

`setup.sh` runs `build-nvim.sh` automatically, after the `update-*` installers so
detection sees them. Set `SKIP_NVIM_BOOTSTRAP=1` to skip the headless plugin sync
(e.g. in CI). `scripts/update-neovim.sh` optionally installs the latest official
Neovim build into `~/.apps/nvim` and prepends it to `PATH` (handy where the distro
package lags).
