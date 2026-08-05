# .sauce

Cross-platform dotfiles + machine setup for Linux (Debian, Fedora, and Arch families),
macOS, and Windows, managed with [chezmoi](https://chezmoi.io).

On macOS, package management routes through [Homebrew](https://brew.sh) (installed
automatically if missing): base packages and CLI tools become `brew` formulae, desktop
apps become `brew --cask`, and the Linux-only pieces (Sway/Wayland configs, freedesktop
`.desktop` launchers, Flatpak, systemd/libvirt) are skipped.

Windows is supported in two modes. For the full dev environment, run this inside **WSL2**
(Ubuntu/Debian) — the entire Linux path applies, minus the GUI desktop stack, which is
gated off automatically. For **native Windows**, a deliberately thin layer deploys the
cross-platform config (Neovim, oh-my-posh, a PowerShell profile) and installs a selected
set of GUI apps + CLI tools through [winget](https://learn.microsoft.com/windows/package-manager/).
See [Windows notes](#windows-notes).

## Quick start

One command bootstraps a fresh machine — installs chezmoi, clones this repo to
`~/.sauce`, and applies everything:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/codyconfer/.sauce/main/bootstrap.sh)
```

If `OP_ACCOUNT` or any `BW_*` variable is set (typically from `.env`), bootstrap also
installs the matching secret-manager CLI, walks you through sign-in, and then re-reads
`.env` so `$(op read ...)` style values resolve before chezmoi runs. See `.env.example`.

It needs `curl`, `git`, and `sudo`. On a minimal image (e.g. a `pacstrap base` Arch
install) `git` and `sudo` are missing — bootstrap installs them for you when it can,
and otherwise tells you to install them as root first.

Already have the repo cloned? Just run `bash ~/.sauce/bootstrap.sh`, or if chezmoi
is installed, `chezmoi init --source=~/.sauce --apply`.

To validate the complete selected configuration without changing dotfiles or installing
packages/apps, pass `--dry-run` (`./bootstrap.sh --dry-run` on Unix or
`./bootstrap.ps1 -DryRun` on Windows). This initializes chezmoi, renders all selected
templates and run scripts, and plans the full apply.

On **native Windows** (PowerShell), bootstrap with winget instead:

```powershell
irm https://raw.githubusercontent.com/codyconfer/.sauce/main/bootstrap.ps1 | iex
```

or, if chezmoi is already installed, `chezmoi init --apply codyconfer` (chezmoi clones the
repo itself). Inside **WSL2** use the `bash` bootstrap above — it just works. See
[Windows notes](#windows-notes).

`chezmoi apply` (aliased to `sauce`) is safe to re-run — it installs base packages,
authenticates GitHub, installs oh-my-posh, deploys all config files, installs the
declared apps/flatpaks, downloads the CLI tools, runs the self-updating tool
installers once, bootstraps Neovim, and sets zsh as your login shell. Each step is
idempotent.

A **base set is always installed** with no prompt: essential packages (git, curl, zsh,
neovim, gcc, make, …), extras (pipx, htop, btop, fish, plus the Nerd Fonts and
zsh-plugins), and the GitHub CLI. On first `init` you then pick from multi-select
lists — emulators (Steam, Wine, QEMU), GUI apps (Firefox, Sway, Alacritty, GNU Radio, qdmr, VS Code,
Zed, Cursor, Ghidra, JetBrains Toolbox, LM Studio, Obsidian, Docker, Codex, Bitwarden, 1Password), flatpaks
(Slack, Discord, Signal, …), CLI/dev tools (the "Access" cloud CLIs plus go, k9s,
rustup, … — every `update-*.sh`), and media players/codecs (VLC, Audacious, Quod Libet,
ffmpeg — the players only on a desktop host, ffmpeg everywhere) — plus yes/no questions:
whether the machine is **headless** (skips the entire desktop layer — emulators, GUI
apps, flatpaks — and adds `k3s` to the tool choices), whether to install the common
network/security CLI tools (nmap, dig,
netcat, tcpdump, mtr, whois, …), and whether to bring up Tailscale. On an Arch host
you also pick a **boot splash theme** — `arch`, `grafana`, `bgrt`, `spinner`, or
`none` (see [the Plymouth themes](#the-plymouth-themes)); `arch` is the default and
`none` leaves boot text-only. Plymouth is never installed on any other family, or
on WSL. (On macOS the same selections install via Homebrew — see
[macOS notes](#macos-notes) below.) Everything defaults to selected, so accepting the
defaults installs the full set. Answers are
saved to `~/.config/chezmoi/chezmoi.toml`; re-run `chezmoi init` to change the
selections.

### Non-interactive bootstrap (`.env`)

Every prompt's default can be pre-seeded from a `SAUCE_*` environment variable, so a
fresh host can be provisioned unattended. Copy `.env.example` → `.env`, edit, and either
run `bash bootstrap.sh` (it auto-sources `$SAUCE_DIR/.env`) or export the vars yourself
before `chezmoi init --apply`:

```sh
cp .env.example .env && $EDITOR .env
set -a; . ./.env; set +a          # export for this shell
bash bootstrap.sh
```

Booleans are `"true"`/`"false"` (e.g. `SAUCE_HEADLESS`, `SAUCE_NET_TOOLS`,
`SAUCE_TAILSCALE`); `SAUCE_PLYMOUTH_THEME` takes a single theme name; list vars are space-separated (`SAUCE_TOOLS="go k9s rustup"`,
`SAUCE_EMULATORS`, `SAUCE_GUI_APPS`, `SAUCE_FLATPAKS`, `SAUCE_MEDIA`, and `SAUCE_WIN_APPS`/
`SAUCE_WIN_TOOLS` on Windows), with the literal `none` selecting an empty set. Unset
vars keep the built-in defaults. Since the prompts are `*Once`, the value is recorded on
first `init` only; `.env` is gitignored. See `.env.example` for the full list.

> **Upgrading an existing install:** the prompt schema changed — `headless`,
> `emulators`, and `media` (VLC/Audacious/Quod Libet/ffmpeg) are new, the GUI-apps list now includes VS Code/Zed/qdmr, and the CLI/dev
> tools list dropped the Access CLIs' always-on status and added `rustup`. Because these
> only prompt once, run `chezmoi init` (accept the defaults) after pulling this change so
> the new selections are recorded — otherwise a bare `chezmoi apply` treats the new keys
> as "none selected" and skips those installers/launchers.

## How it's organized

chezmoi's source lives under `home/` (selected by `.chezmoiroot`), so the repo's
own directories aren't mistaken for things to deploy.

```
~/.sauce/                             # git repo + chezmoi sourceDir
  bootstrap.sh                        # Linux/macOS/WSL: install chezmoi + clone + init --apply
  bootstrap.ps1                       # native Windows: winget git+chezmoi + clone + init --apply
  .chezmoiroot                        # "home" — the source root
  home/
    .chezmoi.toml.tmpl                # generates ~/.config/chezmoi/chezmoi.toml (os/family, prompts)
    .chezmoidata.yaml                 # package lists (essential/extras, netTools, sway, portals, flatpakCatalog, caskCatalog, mediaCatalog, winget)
    .chezmoiexternal.toml.tmpl        # download-only tools (none currently; see skills/add-tool-installer Path B)
    .chezmoiignore                    # per-OS / per-flag exclusions
    Documents/PowerShell/Microsoft.PowerShell_profile.ps1  # → ~/Documents/PowerShell/... (native Windows)
    dot_zshrc  dot_bashrc             # → ~/.zshrc, ~/.bashrc
    dot_config/
      fish/config.fish                # → ~/.config/fish/config.fish
      oh-my-posh/sauce.toml           # → ~/.config/oh-my-posh/sauce.toml (prompt theme)
      nvim/**                         # → ~/.config/nvim (lazy.nvim setup)
      nvim/lua/sauce/generated.lua.tmpl  # LSP/parser list, detected via lookPath
      tmux/tmux.conf                  # → ~/.config/tmux/tmux.conf
      sway/ swaylock/ waybar/         # → ~/.config/* (tracked WM config; Linux only, ignored on macOS)
      fuzzel/ mako/ foot/             #    "
      swayimg/ mpv/ havoc/            #    "  (sway companion tools)
      way-displays/ waylogout/ zskins/ #   "
      xdg-desktop-portal/             #    "  (per-desktop portal backend preferences)
      uwsm/env                        #    "  (session env: PATH/XDG_DATA_DIRS, Wayland-only toolkit backends)
      uwsm/env-sway                   #    "  (session env: GPU pick, cursor, SUDO_ASKPASS)
      alacritty/alacritty.toml        # → ~/.config/alacritty (Linux + macOS; ignored on Windows/WSL)
    create_dot_bashrc.local           # → ~/.bashrc.local (created once, never overwritten)
    dot_local/bin/sauce-askpass       # → ~/.local/bin/sauce-askpass (SUDO_ASKPASS helper; fuzzel password prompt)
    dot_local/share/applications/     # AppImage .desktop launchers (obsidian; Linux only, ignored on macOS)
    .chezmoiscripts/                  # ordered run scripts (see below)
  scripts/
    lib/{config,common,distro,runner}.sh   # shared bash helpers
    update-*.sh                        # self-updating tools that need sudo / vendor installers
    update-all.sh                      # run every update-*.sh
    render-plymouth-theme.sh           # regenerate the Plymouth theme art from assets/plymouth/src
  assets/
    plymouth/{grafana,arch}/           # → /usr/share/plymouth/themes/<theme> (installed by the plymouth step)
    plymouth/src/                      # official Grafana + Arch SVG sources the art is rendered from
  skills/                              # authoring conventions (add-tool-installer, validate-scripts)
```

### The Plymouth themes

Two sauce themes live in `assets/plymouth/`, both [`two-step`](https://gitlab.freedesktop.org/plymouth/plymouth)
themes with the same layout — logo watermark at 38% height, passphrase dialog at
58%, throbber at 78% — differing only in art and palette:

| Theme | Watermark | Palette |
|---|---|---|
| `grafana` | official Grafana horizontal lockup | canvas `#181b1f` → `#111217`, brand gradient `#F55F3E` → `#FF8833`, field `#22252b`/`#363940`, Inter |
| `arch` | official Arch Linux inverted lockup | canvas `#1a1a1a` → `#0d0d0d`, Arch blue `#0f7ab5` → `#1793d1`, field `#242424`/`#3c3c3c`, Noto Sans |

The plymouth step copies the selected one to `/usr/share/plymouth/themes/<theme>/`
and installs its font package (`inter-font` / `noto-fonts`, best-effort — the
mkinitcpio hook falls back to the default sans if it's missing). `arch` is the
default; nothing about Plymouth is installed or configured outside an Arch host —
the prompt is Arch-only, the run script is gated on `arch` and non-WSL, and
`setup_plymouth` independently bails on a non-Arch family, on WSL, and when
`mkinitcpio` or `/etc/mkinitcpio.conf` is absent.

Sources in `assets/plymouth/src/` are unmodified official files: the Grafana
lockup from `grafana.com/static/assets/img/grafana_logo.svg`, the padlock from
`grafana/grafana`'s `public/img/icons/unicons/lock.svg`, and the Arch lockup from
`archlinux.org/static/logos/archlinux-logo-light-scalable.svg`. Both projects'
trademark policies allow scaling the marks but not recoloring or redrawing them,
so the lockups are only ever scaled; the throbber, field, and bullets are
original art in each project's colors.

Regenerate after changing a source or a palette (needs `librsvg` + `imagemagick`).
The `.plymouth` config files are generated too, so palettes live in one place:

```bash
bash scripts/render-plymouth-theme.sh              # both themes at 1x
bash scripts/render-plymouth-theme.sh arch         # just one
SCALE=2 FRAMES=45 bash scripts/render-plymouth-theme.sh
```

Art is authored at 1x logical size because Plymouth composites in logical
coordinates and upscales on HiDPI panels (this one is 208 DPI, so it doubles).
If the result looks soft, re-render at `SCALE=2` and boot with
`PLYMOUTH_FORCE_SCALE=1`.

### The `.chezmoiscripts/` run scripts

chezmoi runs these in name order — `before_` scripts before any files are
written, `after_` scripts once everything is in place:

| script | replaces | when |
|---|---|---|
| `run_once_before_10-base-packages` | `install-base.sh` | once |
| `run_once_before_15-paru` | `setup.sh` paru step — builds the `paru` AUR helper from source (Arch only) | once |
| `run_once_before_17-default-kernel` | `setup.sh` default-kernel step — installs the mainline `linux` kernel and makes it the default systemd-boot entry, so unprivileged user namespaces (needed by Flatpak/bwrap) are available; `linux-hardened`/`linux-lts` stay in the boot menu (Arch only; set `DEFAULT_KERNEL=0` to skip) | once |
| `run_before_18-wifi-powersave` | `setup.sh` wifi-powersave step — drops a NetworkManager conf.d file setting `wifi.powersave = 2` so Intel iwlwifi cards stop tripping mac80211's beacon-loss threshold (Linux, non-WSL; `WIFI_POWERSAVE=0` to skip). Re-checked on every apply — it exits immediately once its `# managed by sauce` marker is in place, so it can self-heal if the file is missing | every apply, no-op once present |
| `run_once_before_19-plymouth` | `setup.sh` plymouth step — installs Plymouth and the theme picked by the `plymouthTheme` prompt, adds the `plymouth` hook ahead of `encrypt` so the LUKS unlock prompt is graphical, adds `quiet splash` to the kernel command line, and rebuilds the initramfs (Arch only; skipped when `plymouthTheme` is `none`, `PLYMOUTH=0` also skips it) | once |
| `run_once_before_20-github-auth` | `setup.sh` github step | once |
| `run_once_before_30-oh-my-posh` | `setup.sh` oh-my-posh step | once |
| `run_onchange_before_38-emulators` | steam/wine/qemu installers (skipped if headless) | on change |
| `run_before_35-fingerprint` | `setup.sh` fingerprint step — installs `fprintd` when a USB fingerprint reader is on the bus (matched by known reader vendor IDs or a `finger` product string in sysfs); PAM is left alone, so enroll with `fprintd-enroll` and wire `pam_fprintd.so` yourself (Linux, non-WSL; `FINGERPRINT=0` to skip). Re-checked on every apply so a reader that appears later still gets picked up, and it exits immediately once `fprintd-enroll` is on PATH | every apply, no-op once installed |
| `run_once_before_36-clamav` | `setup.sh` clamav step — clamav + freshclam, `clamav-freshclam.service` for updates, and a weekly report-only scan timer (Linux, non-WSL; `CLAMAV=0` to skip) | once |
| `run_once_before_37-rslsync` | `setup.sh` rslsync step — installs Resilio Sync from the AUR, creates `<rslsync-home>/sync` (setgid, group `rslsync`), adds your login user to the `rslsync` group, pins access + default ACLs for both accounts, and enables `rslsync.service` (Arch only, opt-in via `rslsync`) | once (opt-in) |
| `run_once_before_39-nvidia` | `setup.sh` nvidia step — installs the NVIDIA open kernel modules + userspace when an NVIDIA GPU is on the PCI bus (Linux, non-WSL; set `NVIDIA=0` to skip) | once |
| `run_onchange_before_40-gui-apps` | firefox/sway/alacritty/gnuradio/sourcegit installers (skipped if headless) | on change |
| `run_onchange_before_45-net-tools` | network/security CLI tools (opt-in via `netTools`) | on change |
| `run_onchange_before_46-media` | media players/codecs — vlc/audacious/quodlibet/ffmpeg, selected via `media` (enables RPM Fusion on Fedora, where vlc and the full ffmpeg build live) | on change |
| `run_onchange_before_50-flatpaks` | flatpak `install-*.sh` (skipped if headless) | on change |
| `run_after_05-zshrc-local` | scaffolds `~/.zshrc.local` when missing (never overwritten) | every apply, no-op once present |
| `run_after_06-fish-user` | scaffolds `~/.config/fish/user.fish` when missing (never overwritten) | every apply, no-op once present |
| `run_once_after_70-run-updaters` | `setup.sh` update loop (always runs fonts + zsh-plugins; installs the `update-*.sh`-backed GUI apps — vscode/zed/qdmr/claude/cursor/ghidra/jetbrains-toolbox/lmstudio/obsidian/docker/codex — when selected; adds `sway-tools` when sway is selected; adds `fleet` when FLEET_URL + FLEET_ENROLL_SECRET are set — there is no prompt for it) | once |
| `run_once_after_75-sway-session` | ly + uwsm login stack, with ly enabled as the default display manager (sway selected, not headless/WSL) | once |
| `run_once_after_76-portals` | `setup.sh` portals step — xdg-desktop-portal backends (wlr for sway, kde for KDE Plasma) | once |
| `run_onchange_after_80-nvim-bootstrap` | `build-nvim.sh` sync tail | on lockfile/toolchain change |
| `run_once_after_90-chsh-zsh` | `setup.sh` chsh | once |
| `run_once_after_95-tailscale` | `setup.sh` tailscale | once (opt-in) |
| `run_onchange_before_40-winget.ps1` | winget GUI apps + CLI tools (native Windows only) | on change |

`run_once_*` run a single time (keyed on content hash); `run_onchange_*` re-run
whenever their rendered content changes (e.g. you edit a package list).

## Testing bootstrap

GitHub Actions validates the full/default bootstrap selection on macOS, native Windows,
Ubuntu, Fedora, Arch Linux, and CachyOS. The apply is a dry run: all selected templates
and run scripts are rendered, while host packages and applications are not installed.

Run the Linux coverage locally with Docker:

```bash
./tests/bootstrap/run-docker.sh              # Ubuntu + Fedora + Arch + CachyOS
./tests/bootstrap/run-docker.sh arch         # one target
./tests/bootstrap/run-docker.sh cachyos      # one target
```

The CachyOS container is forced to `linux/amd64`, so Docker Desktop can emulate it on
Arm-based Macs. The macOS and native-Windows jobs require those host operating systems
and run `tests/bootstrap/test-unix.sh` or `tests/bootstrap/test-windows.ps1` directly.

## Keeping tools current

Two mechanisms, by tool type:

- **Declarative externals** (`home/.chezmoiexternal.toml.tmpl`) — tools that are
  just a downloaded binary/tarball/AppImage into a user directory. chezmoi
  re-downloads each when its `refreshPeriod` lapses, or on
  `chezmoi apply --refresh-externals`. Currently: `sway-font-awesome`
  (per-app window-title icons included by the sway config) and `herdr`
  (a terminal workspace manager for coding agents — single binary into
  `~/.local/bin`, opt-in via the `herdr` tools choice). See
  `skills/add-tool-installer` (Path B) to add one.
- **`scripts/update-*.sh`** — tools that need `sudo`, install into `/usr/local`,
  run a vendor `curl | sh` installer, self-update, or are a plain binary download
  (go, dotnet, gcloud, aws, pyenv, poetry, zed, opencode, claude-code, codex, gcx,
  pi, nvm, wrangler, yarn, azure-cli, vscode, docker, jetbrains-toolbox, rustup,
  fonts, zsh-plugins, loglit, k9s, kubectl, cloudflared) or a source build (tmux).
  Run once at setup, then any
  time via the alias matching the filename (e.g. `update-go`) or `update-all` for all
  of them. The language runtimes run first in every batch, in this order — `go`,
  `rustup`, `dotnet`, `nvm`, `poetry`, `pyenv`, `docker` — and each one leaves a usable
  default in place (`rustup default stable`, PowerShell as a dotnet global tool, the
  latest Node LTS as the nvm `default`, the latest CPython as the pyenv `global`). The
  rest follow in alphabetical order, so the npm-based installers (codex, wrangler, yarn,
  pi) find `npm` on a first run. The order lives in `_DEV_ENV_ORDER`
  (`scripts/lib/runner.sh`).

Most `update-*.sh` are gated by the `tools` init-prompt selection: an external is only
downloaded when its key is selected, and `run_update_scripts` only runs an
`update-*.sh` whose suffix is selected (a manual `update-all` reads the selection
from `chezmoi data`; running `update-go` by hand still works regardless). Two
exceptions, wired via the run-updaters step: `fonts` and `zsh-plugins` are part of the
always-installed base and run unconditionally, while the GUI-oriented ones
(`vscode`, `zed`, `qdmr`, `claude`, `cursor`, `ghidra`, `jetbrains-toolbox`, `lmstudio`,
`obsidian`, `docker`, `codex`, `bitwarden`, `1password`) are selected through the **GUI apps** prompt (and so
skipped on headless/WSL) rather than `tools`.

Distro packages and flatpaks are kept current by the system: the `update` alias
runs `apt upgrade` / `pacman -Syu` / `dnf upgrade` plus `flatpak update` (on macOS it
runs `brew update && brew upgrade && brew upgrade --cask`).

### The sway desktop stack

Selecting **sway** in the GUI apps prompt installs and configures the whole
Wayland desktop, three ways:

- **Distro packages** (`sway:` lists in `.chezmoidata.yaml`, family-aware):
  sway, swaybg, swayidle, swaylock, waybar, fuzzel, foot, mako, grim, slurp,
  grimshot, wl-clipboard, brightnessctl, pavucontrol, mpv, swayimg, wlsunset,
  waypipe, uwsm (+ runtime helpers: libnotify, imagemagick, ddcutil,
  mesa-vulkan-drivers).
- **Desktop portals** (`portals:` in `.chezmoidata.yaml`, installed by
  `run_once_after_76-portals`): `xdg-desktop-portal-wlr` for sway and
  `xdg-desktop-portal-gtk` for KDE Plasma (detected at runtime via
  `startplasma-wayland`, so a Plasma box gets the gtk backend even without sway
  selected). The preference per desktop is pinned by
  `~/.config/xdg-desktop-portal/{sway,kde}-portals.conf`: under sway `wlr` owns
  Screenshot/ScreenCast and `gtk` is the default for everything else (FileChooser
  included, which wlr does not implement). Under KDE `kde` owns every interface
  with `kwallet` for Secret and no GTK fallback — the GTK backend segfaults in
  GTK3's X11 event path when it drives dialogs on a Plasma Wayland session, and
  the Qt backend implements every interface the GTK one does except the
  GNOME-only Lockdown. `xdg-desktop-portal-gtk` is therefore not installed for
  KDE (it stays on disk anyway as a hard dependency of `gtk4` and
  `kde-gtk-config`), and where sway does need it a systemd drop-in
  (`~/.config/systemd/user/xdg-desktop-portal-gtk.service.d/override.conf`) pins
  it to `GDK_BACKEND=wayland` so it cannot fall back to X11.
- **`update-sway-tools.sh`** — companions with no Ubuntu/Debian package, built
  from source into `~/.local/bin` and re-run like any updater
  (`update-sway-tools`): wayshot, sway-overfocus, wl-clip-persist, lumactl,
  zofi, waylogout, havoc, exposway, way-displays, swaycycle, sway-screenshot,
  swaydim, plus Font Awesome 6 / Nerd Fonts Symbols and the Kooha screen
  recorder (flatpak). Also sets swayimg/mpv as xdg-mime defaults.
- **Login stack** — `run_once_after_75-sway-session` installs
  [ly](https://github.com/fairyglade/ly) (the distro package on Arch/Fedora,
  otherwise the latest tag built with a checksummed zig toolchain fetched from
  ziglang.org; `installnoconf` once `/etc/ly/config.ini` exists, so your edits
  survive upgrades) and makes it the default display manager. Each uwsm session
  is written as a desktop entry in `/usr/local/share/wayland-sessions`:
  - `sway` → `uwsm start -N Sway -D sway -e -- sway` (shadows the distro's
    `sway.desktop`)
  - `plasma-uwsm` → `uwsm start -N Plasma -D KDE -e -- startplasma-wayland`,
    added only when KDE Plasma is installed

  `/etc/ly/config.ini` is pinned to those entries only — `waylandsessions` points
  at `/usr/local/share/wayland-sessions` and `xsessions`, `xinitrc`,
  `custom_sessions` and `shell` are switched off, so the greeter lists nothing
  but the uwsm sessions. The stock config is kept as `config.ini.dist-bak`.

  **Greeter size.** ly is a TUI on a VT, so its text size is the console font —
  `config.ini` has no scale, font or DPI key. The step therefore sets `FONT=` in
  `/etc/vconsole.conf` (default `ter-124n`, Terminus 12x24 — exactly 1.5x the
  8x16 built-in), reloads `systemd-vconsole-setup`, and rebuilds the initramfs
  when `consolefont` is in `HOOKS` so the early console matches. `CONSOLE_FONT`
  overrides it (`ter-128n` = 14x28, `ter-132n` = 16x32, `none` leaves the font
  alone); `terminus-font` is installed on demand for any `ter-*` name. Run it
  alone with `bash scripts/setup.sh console-font`. This scales every VT, not just
  ly. On a 2560x1600 panel, 8x16 gives a 320x100 grid and `ter-124n` gives
  213x66.

  The switch is real: the previous display manager is disabled, `getty@tty2` is
  disabled, `ly@tty2.service` is enabled and (on Debian family)
  `/etc/X11/default-display-manager` becomes `/usr/bin/ly`. Revert with
  `sudo systemctl disable ly@tty2.service && sudo systemctl enable sddm`. The
  older greetd and lemurs stacks are torn down on the way through — a
  sauce-managed `/etc/greetd/config.toml` is reverted to its `.dist-bak` (or
  removed), and lemurs' binary, service, PAM entry and `/etc/lemurs` are deleted.

  The uwsm commands name the compositor binary directly and pass
  `-D <name> -e` rather than handing uwsm a session entry ID. uwsm validates
  entries against the desktop-entry spec, and Kubuntu's `plasma.desktop` ships
  without a `Type=` key, so `uwsm start -- plasma.desktop` fails outright;
  without `-e`, uwsm also derives `XDG_CURRENT_DESKTOP` from the executable name
  (`startplasma-wayland:KDE`) instead of plain `KDE`.

Deliberately skipped from the wishlist: `autologin` (ly remembers the last user
and session instead) and `wlrobs` (flatpak OBS ships native PipeWire screen
capture; no flathub plugin exists).

Key sway bindings added: `$mod+h/j/k/l` → sway-overfocus, `$mod+Tab` /
`Mod1+Tab` → group cycle / swaycycle Alt-Tab, `$mod+Shift+e` → waylogout,
`Print` family → wayshot + sway-screenshot, brightness keys → lumactl,
`$mod+x` → zofi launcher, `$mod+Shift+x` → zofi clipboard history,
`$mod+Shift+Return` → havoc, `$mod+z` → exposway, `$mod+Shift+r` → Kooha.

### macOS notes

On macOS the same `tools` selection installs via Homebrew: each Linux-only
`update-*.sh` delegates to `brew` at the top (`scripts/lib/distro.sh` maps the tool to a
formula or cask), so `update-<tool>` and `update-all` work the same way, and
`update-<tool> remove` uninstalls the brew package. Cross-platform vendor installers
(claude-code, codex, opencode, dotnet, nvm, pyenv, poetry, zed, wrangler, yarn,
zsh-plugins, …) run their normal installer on both OSes. The `flatpaks` prompt maps to
Homebrew casks via `caskCatalog` in `.chezmoidata.yaml`; a few Linux-only apps
(easyeffects, lutris) and the Sway stack have no macOS equivalent and are skipped.

### Windows notes

Two independent chezmoi "machines" run off this one repo:

- **WSL2** (Ubuntu/Debian): detected via the `microsoft` kernel marker. The full Debian
  path applies — base packages, CLI tools, shells, oh-my-posh, Neovim, Tailscale — but the
  GUI/desktop layer is gated off automatically (emulators, GUI apps, Sway/Wayland stack,
  Flatpaks, AppImage launchers), since WSL has no display — the same effect as answering
  **yes** to the headless prompt on a bare-metal Linux box. No prompts for those appear.
- **Native Windows**: a thin layer. chezmoi deploys the cross-platform config
  (`~/.config/nvim`, `~/.config/oh-my-posh/sauce.toml`, and a PowerShell profile at
  `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`) and skips the entire bash
  provisioning apparatus, the POSIX shells, and the desktop stack. First `init` prompts two
  multi-select lists — GUI apps (`winApps`) and CLI/dev tools (`winTools`) — which
  `run_onchange_before_40-winget.ps1` installs idempotently through winget. The choice→id
  maps live under `winget:` in `.chezmoidata.yaml`.

  Not everything ports: the Linux-only Flatpaks (easyeffects, lutris) and a few tools with
  no clean winget package (chirp, sonic-pi, plus niche personal tools) are omitted, and
  npm/pipx-only tools (wrangler, claude-code, poetry, pyenv) aren't in the winget set yet.
  The PowerShell profile sets `XDG_CONFIG_HOME` so Neovim finds the shared `~/.config/nvim`.
  Personal tweaks go in `~/Documents/PowerShell/profile.local.ps1` (sourced, never managed).

## Shell config & personal tweaks

The rc files (`~/.zshrc`, `~/.bashrc`, `~/.config/fish/config.fish`) are managed by
chezmoi — edit the source with `chezmoi edit ~/.zshrc` (aliased `sauce-edit`), or
edit in the repo and `chezmoi apply`. Each carries a runtime-guarded env/PATH block
per tool that no-ops when the tool is absent. Both flatpak export dirs
(`~/.local/share/flatpak/exports/bin`, `/var/lib/flatpak/exports/bin`) are on
`PATH`, and `.config/uwsm/env` adds them plus the matching `exports/share` dirs
to `XDG_DATA_DIRS` for the sway session, so flatpak apps are runnable by name and
show up in fuzzel/zofi (ly-launched sessions never read `/etc/profile.d`).

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
