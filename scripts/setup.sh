#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

_data() { chezmoi data --format json 2>/dev/null | jq -r "$@" 2>/dev/null || true; }

setup_base_packages() {
    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" = unknown ]; then
        log_error "unsupported distro (need apt, dnf, or pacman)."
        return 1
    fi
    log_info "Installing base packages for family: $family"

    local -a essential extras
    if [ -n "${ESSENTIAL:-}" ]; then
        read -ra essential <<<"$ESSENTIAL"
    else
        mapfile -t essential < <(_data --arg f "$family" '.packages.essential.common + (.packages.essential[$f] // []) | .[]')
    fi
    if [ -n "${EXTRAS:-}" ]; then
        read -ra extras <<<"$EXTRAS"
    else
        mapfile -t extras < <(_data '.packages.extras.common[]')
    fi
    if [ "$family" = arch ]; then
        local -a arch_extras=()
        local e
        for e in "${extras[@]}"; do
            case "$e" in
                gh)   arch_extras+=(github-cli) ;;
                pipx) arch_extras+=(python-pipx) ;;
                *)    arch_extras+=("$e") ;;
            esac
        done
        extras=("${arch_extras[@]}")
    fi

    pkg_refresh || true

    log_install "Installing essential packages..."
    install_pkgs "${essential[@]}" || { log_error "Failed to install essential packages."; return 1; }

    log_install "Installing extra packages (best-effort)..."
    local p
    for p in "${extras[@]}"; do
        install_pkgs "$p" || log_warn "skipped (unavailable): $p"
    done

    command -v pipx   >/dev/null 2>&1 && pipx ensurepath || true

    log_done "Base packages installed."
}

nvidia_gpus() {
    local d vendor class device found=1
    for d in /sys/bus/pci/devices/*; do
        [ -r "$d/vendor" ] && [ -r "$d/class" ] && [ -r "$d/device" ] || continue
        read -r vendor <"$d/vendor"
        [ "$vendor" = 0x10de ] || continue
        read -r class <"$d/class"
        case "$class" in 0x0300* | 0x0302* | 0x0380*) ;; *) continue ;; esac
        read -r device <"$d/device"
        printf '%s ' "10de:${device#0x}"
        found=0
    done
    return $found
}

nvidia_arch() {
    local -a pkgs=(nvidia-utils nvidia-settings opencl-nvidia nvidia-prime)
    local -a kernels=()
    local k dkms=0
    mapfile -t kernels < <(pacman -Qq linux linux-lts linux-zen linux-hardened 2>/dev/null)
    [ "${#kernels[@]}" -eq 0 ] && kernels=(linux)
    for k in "${kernels[@]}"; do
        case "$k" in
            linux | linux-lts) ;;
            *) dkms=1 ;;
        esac
    done
    if [ "$dkms" -eq 1 ]; then
        pkgs+=(nvidia-open-dkms)
        for k in "${kernels[@]}"; do pkgs+=("$k-headers"); done
    else
        for k in "${kernels[@]}"; do
            [ "$k" = linux ] && pkgs+=(nvidia-open)
            [ "$k" = linux-lts ] && pkgs+=(nvidia-open-lts)
        done
    fi
    install_pkgs "${pkgs[@]}" || return 1
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        install_pkgs lib32-nvidia-utils || log_warn "lib32-nvidia-utils failed; 32-bit games may not find the driver."
    else
        log_hint "multilib is disabled, so lib32-nvidia-utils was skipped (Steam needs it)."
    fi
}

nvidia_debian() {
    command -v ubuntu-drivers >/dev/null 2>&1 || install_pkgs ubuntu-drivers-common || true
    if command -v ubuntu-drivers >/dev/null 2>&1; then
        log_install "Letting ubuntu-drivers pick the recommended driver..."
        sudo ubuntu-drivers install && return 0
        log_warn "ubuntu-drivers install failed; looking for the Debian driver packages."
    fi
    if apt-cache policy nvidia-open-kernel-dkms 2>/dev/null | grep -q 'Candidate: [0-9]'; then
        install_pkgs nvidia-open-kernel-dkms nvidia-driver firmware-misc-nonfree && return 0
        log_error "Driver install failed; check that non-free and non-free-firmware are enabled."
        return 1
    fi
    log_error "No NVIDIA driver package is available: on Ubuntu run 'sudo ubuntu-drivers install' by hand, on Debian enable the non-free and non-free-firmware components."
    return 1
}

nvidia_fedora() {
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        log_install "Enabling RPM Fusion for the NVIDIA driver..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
            || log_warn "Could not enable RPM Fusion."
    fi
    install_pkgs akmod-nvidia xorg-x11-drv-nvidia-cuda || return 1
}

setup_nvidia() {
    local family
    family="${FAMILY:-$(detect_family)}"
    case "$family" in
        debian | fedora | arch) ;;
        *) log_info "NVIDIA driver setup is Linux-only — skipping on $family."; return 0 ;;
    esac
    if [ "${NVIDIA:-1}" = 0 ]; then
        log_info "NVIDIA=0 — skipping driver setup."
        return 0
    fi

    local gpus
    gpus="$(nvidia_gpus)" || {
        log_info "No NVIDIA GPU on the PCI bus — skipping driver setup."
        return 0
    }
    log_found "NVIDIA GPU detected (${gpus% })."

    if command -v nvidia-smi >/dev/null 2>&1 \
        && nvidia-smi --query-gpu=driver_version --format=csv,noheader >/dev/null 2>&1; then
        log_info "Driver already loaded: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)."
        return 0
    fi

    log_install "Installing the NVIDIA open kernel modules and userspace..."
    case "$family" in
        arch)   nvidia_arch ;;
        debian) nvidia_debian ;;
        fedora) nvidia_fedora ;;
    esac || { log_error "NVIDIA driver install failed."; return 1; }

    log_done "NVIDIA drivers installed."
    log_hint "Reboot to load the module. Under Secure Boot the module must be signed (enroll a MOK), or the GPU falls back to nouveau."
}

CLAMAV_SCAN_BIN=/usr/local/bin/sauce-clamav-scan
CLAMAV_UNIT_DIR=/etc/systemd/system

clamav_pkgs() {
    case "$1" in
        debian) echo "clamav clamav-daemon clamav-freshclam" ;;
        fedora) echo "clamav clamav-update clamd" ;;
        arch)   echo "clamav" ;;
        *)      return 1 ;;
    esac
}

clamav_daemon_unit() {
    case "$1" in
        fedora) echo "clamd@scan.service" ;;
        *)      echo "clamav-daemon.service" ;;
    esac
}

write_clamav_scanner() {
    local paths="$1"
    sudo tee "$CLAMAV_SCAN_BIN" >/dev/null <<-EOF
	#!/usr/bin/env bash
	set -uo pipefail
	PATHS="\${CLAMAV_SCAN_PATHS:-$paths}"
	EXCLUDE_DIRS='^/(proc|sys|dev|run|snap|var/lib/docker|var/lib/flatpak)'
	SCANNER=clamscan
	if command -v clamdscan >/dev/null 2>&1 \
	    && systemctl is-active --quiet clamav-daemon.service 2>/dev/null; then
	    SCANNER=clamdscan
	fi
	echo "sauce-clamav-scan: \$SCANNER over \$PATHS"
	# shellcheck disable=SC2086
	if [ "\$SCANNER" = clamdscan ]; then
	    clamdscan --multiscan --fdpass --infected \$PATHS
	else
	    clamscan --recursive --infected --exclude-dir="\$EXCLUDE_DIRS" \$PATHS
	fi
	rc=\$?
	case "\$rc" in
	    0) echo "sauce-clamav-scan: clean" ;;
	    1) echo "sauce-clamav-scan: INFECTED FILES FOUND (nothing was deleted or quarantined)" ;;
	    *) echo "sauce-clamav-scan: scanner exited \$rc" ;;
	esac
	exit 0
	EOF
    sudo chmod 0755 "$CLAMAV_SCAN_BIN"
}

write_clamav_units() {
    local schedule="$1"
    sudo tee "$CLAMAV_UNIT_DIR/sauce-clamav-scan.service" >/dev/null <<-EOF
	[Unit]
	Description=ClamAV scan (managed by sauce)
	Documentation=man:clamscan(1)
	After=clamav-freshclam.service

	[Service]
	Type=oneshot
	ExecStart=$CLAMAV_SCAN_BIN
	Nice=19
	IOSchedulingClass=idle
	CPUSchedulingPolicy=idle
	EOF
    sudo tee "$CLAMAV_UNIT_DIR/sauce-clamav-scan.timer" >/dev/null <<-EOF
	[Unit]
	Description=Scheduled ClamAV scan (managed by sauce)

	[Timer]
	OnCalendar=$schedule
	RandomizedDelaySec=1h
	Persistent=true

	[Install]
	WantedBy=timers.target
	EOF
}

setup_clamav() {
    local family
    family="${FAMILY:-$(detect_family)}"
    local -a pkgs=()
    local pkglist
    if ! pkglist="$(clamav_pkgs "$family")"; then
        log_info "ClamAV setup is Linux-only — skipping on $family."
        return 0
    fi
    if [ "${CLAMAV:-1}" = 0 ]; then
        log_info "CLAMAV=0 — skipping ClamAV setup."
        return 0
    fi
    read -ra pkgs <<<"$pkglist"

    log_install "Installing ClamAV (${pkgs[*]})..."
    install_pkgs "${pkgs[@]}" || { log_error "ClamAV install failed."; return 1; }

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "no systemd here; ClamAV is installed but nothing was scheduled."
        return 0
    fi

    log_install "Enabling signature updates (clamav-freshclam.service)..."
    sudo systemctl enable clamav-freshclam.service \
        || log_warn "could not enable clamav-freshclam.service."
    sudo systemctl start clamav-freshclam.service \
        || log_warn "clamav-freshclam did not start; run 'sudo freshclam' once by hand."

    write_clamav_scanner "${CLAMAV_SCAN_PATHS:-/home}"
    write_clamav_units "${CLAMAV_SCAN_SCHEDULE:-Sun *-*-* 03:00:00}"
    sudo systemctl daemon-reload || true
    sudo systemctl enable sauce-clamav-scan.timer \
        || log_warn "could not enable sauce-clamav-scan.timer."
    sudo systemctl start sauce-clamav-scan.timer \
        || log_warn "could not start sauce-clamav-scan.timer."

    if [ "${CLAMAV_DAEMON:-0}" = 1 ]; then
        local unit
        unit="$(clamav_daemon_unit "$family")"
        log_install "Enabling the resident scanner ($unit)..."
        sudo systemctl enable --now "$unit" || log_warn "could not enable $unit."
    else
        log_hint "The resident clamd daemon stays off (it holds the signature set in RAM); set CLAMAV_DAEMON=1 to enable it."
    fi

    log_done "ClamAV ready: freshclam updates on, scan timer ${CLAMAV_SCAN_SCHEDULE:-Sun *-*-* 03:00:00} over ${CLAMAV_SCAN_PATHS:-/home}."
    log_hint "Scans report only — nothing is deleted or quarantined. Results: journalctl -u sauce-clamav-scan.service"
}

setup_github_auth() {
    command -v gh >/dev/null 2>&1 || { log_warn "gh not installed; skipping GitHub auth."; return 0; }

    if gh auth status >/dev/null 2>&1; then
        log_info "GitHub already authenticated."
    else
        log_info "Authenticating with GitHub over SSH..."
        gh auth login -p ssh || { log_warn "gh auth login failed or was skipped."; return 0; }
    fi
    gh auth setup-git || log_warn "gh auth setup-git failed."
}

setup_paru() {
    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" != arch ]; then
        log_info "paru is an Arch AUR helper — skipping on $family."
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        log_info "paru already installed."
        return 0
    fi
    if [ "$(id -u)" -eq 0 ]; then
        log_warn "makepkg refuses to run as root; install paru from a normal user account."
        return 0
    fi

    install_pkgs git base-devel || { log_error "Could not install the paru build dependencies."; return 1; }

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"; trap - RETURN' RETURN

    log_download "Cloning paru from the AUR..."
    git clone --quiet --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru" \
        || { log_error "Could not clone paru from the AUR."; return 1; }

    log_install "Building paru from source — it links against the local libalpm, unlike paru-bin."
    log_hint "This pulls the rust toolchain and takes a few minutes; makepkg may ask for your sudo password."
    ( cd "$tmp/paru" && makepkg -si --noconfirm --needed ) \
        || { log_error "makepkg failed; build paru manually from https://aur.archlinux.org/paru.git"; return 1; }

    log_done "paru installed -> $(command -v paru)"
}

setup_oh_my_posh() {
    if command -v oh-my-posh >/dev/null 2>&1; then
        log_info "oh-my-posh already installed."
        return 0
    fi
    log_download "Installing oh-my-posh..."
    fetch https://ohmyposh.dev/install.sh | bash -s
}

setup_run_updaters() {
    if [ ! -f "$HOME/.sauce/scripts/update-all.sh" ]; then
        log_warn "scripts/update-all.sh not found; skipping updaters."
        return 0
    fi
    log_found "Running self-updating tool installers (scripts/update-all.sh)..."
    bash "$HOME/.sauce/scripts/update-all.sh" \
        || log_warn "Some updaters failed; re-run individually (e.g. 'update-go') or 'update-all'."
}

setup_chsh_zsh() {
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    [ -z "$zsh_path" ] && { log_warn "zsh not found; skipping chsh."; return 0; }
    if [ "${SHELL:-}" = "$zsh_path" ]; then
        log_info "Login shell already zsh."
        return 0
    fi
    log_info "Setting zsh as your login shell..."
    chsh -s "$zsh_path" || log_warn "chsh failed; set zsh as your login shell manually."
}

LY_REPO="fairyglade/ly"
LY_SESSIONS="/usr/local/share/wayland-sessions"
LY_TTY=2

ly_version() {
    command -v ly >/dev/null 2>&1 || return 0
    ly --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

ly_latest_tag() {
    fetch "https://api.github.com/repos/$LY_REPO/tags?per_page=100" \
        | jq -r '.[].name' \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V | tail -1
}

ly_build_deps() {
    local family="$1"
    case "$family" in
        debian) install_pkgs git libpam0g-dev libxcb1-dev ;;
        fedora) install_pkgs git pam-devel libxcb-devel ;;
        arch)   install_pkgs git pam libxcb ;;
        *)      return 1 ;;
    esac
}

ly_zig() {
    local want="$1" tmp="$2" target url shasum have
    have="$(zig version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+')"
    if [ -n "$have" ] && [ "$have" = "$(echo "$want" | cut -d. -f1,2)" ]; then
        ZIG="$(command -v zig)"
        return 0
    fi

    case "$(uname -m)" in
        x86_64)          target=x86_64-linux ;;
        aarch64 | arm64) target=aarch64-linux ;;
        riscv64)         target=riscv64-linux ;;
        armv7l | armv7)  target=arm-linux ;;
        *) log_error "No zig build published for $(uname -m)."; return 1 ;;
    esac

    local index
    index="$(fetch https://ziglang.org/download/index.json)" || return 1
    url="$(jq -r --arg v "$want" --arg t "$target" '.[$v][$t].tarball // empty' <<<"$index")"
    shasum="$(jq -r --arg v "$want" --arg t "$target" '.[$v][$t].shasum // empty' <<<"$index")"
    [ -n "$url" ] || { log_error "zig $want is not published for $target."; return 1; }

    log_download "Downloading zig $want ($target) to build ly..."
    download "$url" "$tmp/zig.tar.xz" || return 1
    verify_sha256 "$shasum" "$tmp/zig.tar.xz" || return 1
    ensure_dir "$tmp/zig"
    tar -C "$tmp/zig" --strip-components=1 -xJf "$tmp/zig.tar.xz" || return 1
    ZIG="$tmp/zig/zig"
}

ly_from_source() {
    local family="$1" tag="$2" tmp="$3" src want step
    src="$tmp/ly"
    ensure_dir "$src"

    log_download "Downloading ly $tag source..."
    download "https://github.com/$LY_REPO/archive/refs/tags/$tag.tar.gz" "$tmp/ly.tar.gz" || return 1
    tar -C "$src" --strip-components=1 -xzf "$tmp/ly.tar.gz" || return 1

    want="$(grep -oE 'minimum_zig_version *= *"[0-9.]+"' "$src/build.zig.zon" \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    ly_build_deps "$family" || log_warn "Could not install every ly build dependency; trying anyway."
    ly_zig "${want:-0.16.0}" "$tmp" || return 1

    step=installexe
    [ -f /etc/ly/config.ini ] && step=installnoconf

    log_install "Building ly $tag (zig ${want:-0.16.0}, $step)..."
    (
        cd "$src" || exit 1
        "$ZIG" build --global-cache-dir "$tmp/zig-global" -Doptimize=ReleaseSafe \
            -Dinit_system=systemd -Ddefault_tty="$LY_TTY" || exit 1
        sudo "$ZIG" build "$step" --global-cache-dir "$tmp/zig-global" \
            -Doptimize=ReleaseSafe -Dinit_system=systemd -Ddefault_tty="$LY_TTY"
    ) || return 1
    sudo chown -R "$(id -u):$(id -g)" "$tmp" 2>/dev/null || true
    sudo systemctl daemon-reload || true
}

install_ly() {
    local family="$1" tmp="$2" latest
    case "$family" in
        fedora | arch)
            if install_pkgs ly; then
                log_done "ly installed from the distro repos."
                return 0
            fi
            ;;
    esac

    latest="$(ly_latest_tag)"
    if [ -z "$latest" ]; then
        log_error "Could not determine the latest ly version."
        return 1
    fi

    version_gate "ly" "$(ly_version)" "$latest" && return 0

    ly_from_source "$family" "$latest" "$tmp" || return 1
    log_done "ly $latest installed -> /usr/bin/ly"
}

ly_set() {
    local key="$1" value="$2" file=/etc/ly/config.ini
    if ! sudo grep -qE "^[[:space:]]*$key[[:space:]]*=" "$file"; then
        log_warn "ly config has no '$key' key (older ly?); left untouched."
        return 0
    fi
    sudo sed -i -E "s|^[[:space:]]*($key)[[:space:]]*=.*|\1 = $value|" "$file"
}

configure_ly() {
    local file=/etc/ly/config.ini
    if [ ! -f "$file" ]; then
        log_warn "$file not found; skipping ly configuration."
        return 0
    fi
    if ! sudo grep -q "managed by sauce" "$file"; then
        [ -f "$file.dist-bak" ] || sudo cp -a "$file" "$file.dist-bak"
        sudo sed -i "1i # managed by sauce: only the uwsm session entries in $LY_SESSIONS are listed" "$file"
    fi

    ly_set waylandsessions "$LY_SESSIONS"
    ly_set xsessions null
    ly_set xinitrc null
    ly_set shell false
    ly_set custom_sessions null
    log_done "ly lists only the uwsm sessions in $LY_SESSIONS."
}

write_uwsm_session() {
    local id="$1" name="$2" comment="$3" desktop_names="$4" cmd="$5"
    sudo mkdir -p "$LY_SESSIONS"
    sudo tee "$LY_SESSIONS/$id.desktop" >/dev/null <<-EOF
	[Desktop Entry]
	Name=$name
	Comment=$comment
	Exec=$cmd
	TryExec=uwsm
	Type=Application
	DesktopNames=$desktop_names
	EOF
}

retire_session_entry() {
    local entry="$1"
    [ -e "$entry" ] || return 0
    if ! command -v dpkg-divert >/dev/null 2>&1; then
        log_info "Left the package-owned $entry alone; ly only lists $LY_SESSIONS."
        return 0
    fi
    [ -n "$(dpkg-divert --list "$entry")" ] && return 0
    sudo dpkg-divert --add --rename --divert "$entry.sauce-disabled" "$entry" >/dev/null
    log_clean "Diverted $entry (restore with: sudo dpkg-divert --remove $entry)."
}

retire_greetd() {
    local current_dm="$1"
    [ "$current_dm" = greetd ] && return 0
    [ -f /etc/greetd/config.toml ] || return 0
    sudo grep -q "managed by sauce" /etc/greetd/config.toml || return 0
    if [ -f /etc/greetd/config.toml.dist-bak ]; then
        sudo mv -f /etc/greetd/config.toml.dist-bak /etc/greetd/config.toml
        log_clean "Restored the packaged greetd config; sauce no longer manages greetd."
    else
        sudo rm -f /etc/greetd/config.toml
        log_clean "Removed the sauce-managed /etc/greetd/config.toml."
    fi
    log_hint "greetd is unused now — uninstall it with your package manager if you want it gone."
}

retire_lemurs() {
    local family="$1"
    [ -e /usr/bin/lemurs ] || [ -d /etc/lemurs ] \
        || [ -e /etc/systemd/system/lemurs.service ] || return 0

    sudo systemctl disable --now lemurs.service >/dev/null 2>&1 || true
    sudo rm -f /etc/systemd/system/lemurs.service /etc/pam.d/lemurs
    sudo rm -rf /etc/lemurs
    if [ "$family" = arch ] && pacman -Qq lemurs >/dev/null 2>&1; then
        remove_pkgs lemurs || log_warn "pacman could not remove lemurs."
    else
        sudo rm -f /usr/bin/lemurs
    fi
    sudo systemctl daemon-reload || true
    log_clean "Removed the old lemurs login stack (binary, /etc/lemurs, service, PAM entry)."
}

ly_unit() {
    local u
    for u in /usr/lib/systemd/system /lib/systemd/system /etc/systemd/system; do
        [ -f "$u/ly@.service" ] && { echo "ly@tty$LY_TTY.service"; return 0; }
    done
    for u in /usr/lib/systemd/system /lib/systemd/system /etc/systemd/system; do
        [ -f "$u/ly.service" ] && { echo "ly.service"; return 0; }
    done
    return 1
}

enable_ly() {
    local current_dm="$1" unit
    unit="$(ly_unit)" || { log_warn "No ly systemd unit found; not switching display managers."; return 1; }

    if [ -n "$current_dm" ] && [ "${current_dm#ly}" = "$current_dm" ]; then
        sudo systemctl disable "$current_dm.service" >/dev/null 2>&1 \
            && log_clean "Disabled $current_dm."
    fi
    sudo systemctl disable "getty@tty$LY_TTY.service" >/dev/null 2>&1 || true
    sudo systemctl enable "$unit" || { log_error "Could not enable $unit."; return 1; }
    if [ -f /etc/X11/default-display-manager ] \
        && [ "$(cat /etc/X11/default-display-manager)" != /usr/bin/ly ]; then
        sudo cp -a /etc/X11/default-display-manager /etc/X11/default-display-manager.dist-bak
        echo /usr/bin/ly | sudo tee /etc/X11/default-display-manager >/dev/null
    fi
    log_done "ly is the default display manager ($unit, tty$LY_TTY) from the next boot."
    log_hint "Revert with: sudo systemctl disable $unit && sudo systemctl enable ${current_dm:-sddm}"
}

setup_sway_session() {
    if [ "${SWAY_SESSION:-}" != 1 ]; then
        local sel
        sel="$(_data '.guiApps | index("sway")')"
        if [ -z "$sel" ] || [ "$sel" = null ]; then
            log_info "sway not selected — skipping the sway session stack."
            return 0
        fi
    fi

    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" = macos ]; then
        log_info "sway session stack is Linux-only — skipping on macOS."
        return 0
    fi

    log_info "Installing the sway login stack (ly + uwsm)..."

    local current_dm=""
    if [ -f /etc/X11/default-display-manager ]; then
        current_dm="$(basename "$(cat /etc/X11/default-display-manager)")"
    elif [ -L /etc/systemd/system/display-manager.service ]; then
        current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    fi

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"; trap - RETURN' RETURN

    install_ly "$family" "$tmp" || { log_warn "ly install failed."; return 1; }
    configure_ly

    write_uwsm_session sway "Sway" \
        "Sway tiling Wayland compositor, managed by uwsm" \
        "sway" \
        "uwsm start -N Sway -D sway -e -- sway"
    sudo rm -f /usr/share/wayland-sessions/sway-uwsm.desktop

    if command -v startplasma-wayland >/dev/null 2>&1; then
        write_uwsm_session plasma-uwsm "Plasma (UWSM)" \
            "KDE Plasma Wayland session, managed by uwsm" \
            "KDE" \
            "uwsm start -N Plasma -D KDE -e -- startplasma-wayland"
        log_info "Added a UWSM wrapper for the KDE Plasma Wayland session."
        retire_session_entry /usr/share/wayland-sessions/plasma.desktop
    fi

    retire_greetd "$current_dm"
    retire_lemurs "$family"

    enable_ly "$current_dm"
}

setup_portals() {
    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" = macos ]; then
        log_info "xdg-desktop-portal is Linux-only — skipping on macOS."
        return 0
    fi

    local -a desktops=()
    local sway="${SWAY_PORTALS:-}"
    if [ -z "$sway" ]; then
        local sel
        sel="$(_data '.guiApps | index("sway")')"
        [ -n "$sel" ] && [ "$sel" != null ] && sway=1
    fi
    [ "$sway" = 1 ] && desktops+=(sway)
    command -v startplasma-wayland >/dev/null 2>&1 && desktops+=(kde)

    if [ "${#desktops[@]}" -eq 0 ]; then
        log_info "neither sway nor KDE Plasma is present — skipping portal backends."
        return 0
    fi

    local -a pkgs=() dpkgs=()
    local d var
    for d in "${desktops[@]}"; do
        var="PORTAL_PKGS_${d^^}"
        if [ -n "${!var:-}" ]; then
            read -ra dpkgs <<<"${!var}"
        else
            mapfile -t dpkgs < <(_data --arg d "$d" '.portals[$d][]?')
        fi
        pkgs+=("${dpkgs[@]}")
    done
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | awk 'NF && !seen[$0]++')

    if [ "${#pkgs[@]}" -eq 0 ]; then
        log_warn "no portal packages resolved from chezmoi data; skipping."
        return 0
    fi

    log_install "Installing xdg-desktop-portal backends for: ${desktops[*]}"
    local p
    for p in "${pkgs[@]}"; do
        install_pkgs "$p" || log_warn "skipped (unavailable): $p"
    done
    log_done "Portal backends installed (wlr under sway, gtk under KDE Plasma)."
    log_hint "Backend preferences live in ~/.config/xdg-desktop-portal/{sway,kde}-portals.conf; log out and back in to apply."
}

setup_tailscale() {
    local on
    on="${TAILSCALE:-$(_data '.tailscale')}"
    if [ "$on" != true ]; then
        log_info "tailscale=false — skipping Tailscale setup."
        return 0
    fi
    if ! command -v tailscale >/dev/null 2>&1; then
        if [ "$(uname -s)" = Darwin ]; then
            log_download "Installing Tailscale (Homebrew cask)..."
            install_cask tailscale || { log_warn "tailscale install failed."; return 0; }
            log_hint "On macOS, bring up Tailscale from the menu-bar app (the 'tailscale' CLI is inside Tailscale.app)."
            return 0
        fi
        log_download "Installing Tailscale..."
        fetch https://tailscale.com/install.sh | sh || { log_warn "tailscale install failed."; return 0; }
    fi
    sudo tailscale up
}

case "${1:-all}" in
    base-packages) setup_base_packages ;;
    paru)          setup_paru ;;
    nvidia)        setup_nvidia ;;
    clamav)        setup_clamav ;;
    github-auth)   setup_github_auth ;;
    oh-my-posh)    setup_oh_my_posh ;;
    run-updaters)  setup_run_updaters ;;
    sway-session)  setup_sway_session ;;
    portals)       setup_portals ;;
    chsh-zsh)      setup_chsh_zsh ;;
    tailscale)     setup_tailscale ;;
    all)
        setup_base_packages
        setup_paru
        setup_nvidia
        setup_clamav
        setup_github_auth
        setup_oh_my_posh
        setup_run_updaters
        setup_sway_session
        setup_portals
        setup_chsh_zsh
        setup_tailscale
        ;;
    *) log_error "unknown setup step: ${1:-}"; exit 2 ;;
esac
