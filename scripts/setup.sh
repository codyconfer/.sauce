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

    local appimages
    appimages="$(_data '[.guiApps // [] | .[] | select(. == "cursor" or . == "obsidian" or . == "lmstudio")] | length')"
    if [ -n "$appimages" ] && [ "$appimages" != 0 ]; then
        ensure_libfuse2 || true
    fi

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

setup_rslsync() {
    local family on
    family="${FAMILY:-$(detect_family)}"
    on="${RSLSYNC:-$(_data '.rslsync')}"
    if [ "$on" != true ]; then
        log_info "rslsync=false — skipping Resilio Sync setup."
        return 0
    fi
    if [ "$family" != arch ]; then
        log_info "rslsync setup is implemented for Arch only — skipping on $family."
        log_hint "On $family, install Resilio Sync from https://help.resilio.com/ and re-run to provision the share."
        return 0
    fi

    if ! pacman -Qq rslsync >/dev/null 2>&1; then
        local helper="" h
        for h in paru yay; do
            command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }
        done
        if [ -z "$helper" ]; then
            log_error "rslsync ships as an AUR package — install paru or yay first."
            return 1
        fi
        log_install "Installing Resilio Sync from the AUR via $helper..."
        "$helper" -S --needed --noconfirm rslsync \
            || { log_error "rslsync install failed."; return 1; }
    else
        log_info "rslsync is already installed."
    fi

    command -v systemd-sysusers >/dev/null 2>&1 && sudo systemd-sysusers >/dev/null 2>&1

    local rs_home
    rs_home=$(getent passwd rslsync | cut -d: -f6)
    if [ -z "$rs_home" ]; then
        log_error "the rslsync user does not exist; cannot place the sync folder."
        return 1
    fi
    local share="$rs_home/sync"

    log_install "Creating the shared sync folder at $share..."
    sudo install -d -o rslsync -g rslsync -m 2775 "$share" \
        || { log_error "could not create $share."; return 1; }

    local u="${SUDO_USER:-${USER:-$(id -un)}}"
    if [ -n "$u" ] && [ "$u" != root ]; then
        if id -nG "$u" 2>/dev/null | tr ' ' '\n' | grep -qx rslsync; then
            log_info "$u is already in the rslsync group."
        else
            log_install "Adding $u to the rslsync group..."
            sudo usermod -aG rslsync "$u" || log_warn "could not add $u to the rslsync group."
            log_hint "Log out and back in (or run 'newgrp rslsync') for the group change to take effect."
        fi
    fi

    if ! command -v setfacl >/dev/null 2>&1; then
        install_pkgs acl || log_warn "could not install acl; falling back to group permissions only."
    fi
    if command -v setfacl >/dev/null 2>&1; then
        log_install "Granting rslsync and $u full access to $share via ACLs..."
        sudo setfacl -R -m "u:rslsync:rwX,u:$u:rwX" "$share" \
            || log_warn "could not set access ACLs on $share."
        sudo setfacl -R -m "d:u:rslsync:rwX,d:u:$u:rwX" "$share" \
            || log_warn "could not set default ACLs on $share."
    fi

    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl daemon-reload || true
        log_install "Enabling the rslsync system service..."
        sudo systemctl enable --now rslsync.service \
            || log_warn "could not enable rslsync.service."
    fi

    log_done "Resilio Sync ready: shared folder $share, writable by rslsync and $u."
    log_hint "Web UI: http://localhost:8888 — add $share there as a synced folder."
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

CONSOLE_FONT_DIR=/usr/share/kbd/consolefonts
VCONSOLE_CONF=/etc/vconsole.conf

console_font_available() {
    [ -n "$(find "$CONSOLE_FONT_DIR" -maxdepth 1 -name "$1.psf*" -print -quit 2>/dev/null)" ]
}

console_font_current() {
    sed -nE 's/^[[:space:]]*FONT=[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' "$VCONSOLE_CONF" 2>/dev/null | tail -n1
}

vconsole_set() {
    local key="$1" value="$2"
    if sudo grep -qE "^[[:space:]]*$key=" "$VCONSOLE_CONF" 2>/dev/null; then
        sudo sed -i -E "s|^[[:space:]]*$key=.*|$key=$value|" "$VCONSOLE_CONF"
    else
        printf '%s=%s\n' "$key" "$value" | sudo tee -a "$VCONSOLE_CONF" >/dev/null
    fi
}

setup_console_font() {
    local family font current
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" = macos ]; then
        log_info "The console font is a Linux VT setting — skipping on macOS."
        return 0
    fi
    font="${CONSOLE_FONT:-ter-124n}"
    if [ "$font" = none ]; then
        log_info "CONSOLE_FONT=none — leaving the console font alone."
        return 0
    fi

    if ! console_font_available "$font"; then
        case "$font" in
            ter-*) install_pkgs terminus-font >/dev/null 2>&1 || true ;;
        esac
    fi
    if ! console_font_available "$font"; then
        log_warn "console font '$font' is not in $CONSOLE_FONT_DIR; leaving the console font alone."
        return 0
    fi

    current="$(console_font_current)"
    if [ "$current" = "$font" ]; then
        log_info "The console font is already $font (ly renders at that size)."
        return 0
    fi

    log_install "Setting the console font to $font so ly and the VTs render larger..."
    vconsole_set FONT "$font" || { log_error "could not write FONT to $VCONSOLE_CONF."; return 1; }
    sudo systemctl restart systemd-vconsole-setup.service >/dev/null 2>&1 \
        || log_warn "systemd-vconsole-setup did not reload; the font applies on the next boot."

    if mkinitcpio_hooks_read && mkinitcpio_has_hook consolefont; then
        log_install "Rebuilding the initramfs so the consolefont hook picks up $font..."
        sudo mkinitcpio -P >/dev/null 2>&1 \
            || log_warn "mkinitcpio -P failed; run it by hand for the early-boot console."
    fi

    log_done "Console font is $font; ly scales with it."
    log_hint "CONSOLE_FONT picks another font (ter-128n / ter-132n go bigger, none leaves it alone); '$current' was the previous value."
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
    setup_console_font

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

setup_default_kernel() {
    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" != arch ]; then
        log_info "Default-kernel selection is Arch-only — skipping on $family."
        return 0
    fi
    if [ "${DEFAULT_KERNEL:-1}" = 0 ]; then
        log_info "DEFAULT_KERNEL=0 — leaving the default boot entry alone."
        return 0
    fi

    if ! pacman -Qq linux >/dev/null 2>&1; then
        log_install "Installing the mainline kernel (linux, linux-headers)..."
        install_pkgs linux linux-headers \
            || { log_error "mainline kernel install failed."; return 1; }
    fi

    if ! command -v bootctl >/dev/null 2>&1 || ! sudo bootctl is-installed >/dev/null 2>&1; then
        log_info "systemd-boot is not the bootloader here — set the default kernel in your own bootloader."
        return 0
    fi

    local entry
    for entry in arch-linux.efi arch.conf linux.conf; do
        if sudo bootctl list 2>/dev/null | grep -qF "$entry"; then
            log_info "Making $entry the default boot entry (mainline kernel)..."
            sudo bootctl set-default "$entry" \
                || { log_warn "could not set $entry as the default boot entry."; return 0; }
            log_done "Default boot entry is now $entry; linux-hardened and linux-lts stay available in the menu."
            log_hint "Unprivileged user namespaces are enabled on mainline, which is what Flatpak/bwrap needs."
            return 0
        fi
    done
    log_warn "no mainline 'linux' boot entry found in 'bootctl list'; run 'sudo mkinitcpio -P' and re-run this step."
}

MKINITCPIO_CONF=/etc/mkinitcpio.conf
MKINITCPIO_HOOKS=()
PLYMOUTH_ASSETS="$SCRIPT_DIR/../assets/plymouth"

plymouth_theme_is_sauce() {
    [ -f "$PLYMOUTH_ASSETS/$1/$1.plymouth" ]
}

plymouth_theme_is_current() {
    local dst="/usr/share/plymouth/themes/$1"
    [ -d "$dst" ] || return 1
    diff -rq "$PLYMOUTH_ASSETS/$1" "$dst" >/dev/null 2>&1
}

plymouth_theme_font_pkg() {
    case "$1" in
        grafana) echo inter-font ;;
        arch)    echo noto-fonts ;;
    esac
}

plymouth_theme_install() {
    local theme="$1" src dst font
    src="$PLYMOUTH_ASSETS/$theme"
    dst="/usr/share/plymouth/themes/$theme"
    if ! plymouth_theme_is_sauce "$theme"; then
        log_warn "no $theme theme at $src; run 'scripts/render-plymouth-theme.sh $theme' first."
        return 1
    fi

    log_install "Installing the $theme Plymouth theme into $dst..."
    font="$(plymouth_theme_font_pkg "$theme")"
    if [ -n "$font" ]; then
        install_pkgs "$font" >/dev/null 2>&1 \
            || log_warn "$font is unavailable; the theme falls back to the default sans font."
    fi
    sudo install -d -m 0755 "$dst" || { log_error "could not create $dst."; return 1; }
    sudo find "$dst" -maxdepth 1 -type f -delete 2>/dev/null || true
    sudo install -m 0644 "$src"/* "$dst"/ \
        || { log_error "could not copy the theme into $dst."; return 1; }
}

mkinitcpio_hooks_read() {
    local raw
    raw="$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\).*/\1/p' "$MKINITCPIO_CONF" | tail -n1)"
    [ -n "$raw" ] || return 1
    read -ra MKINITCPIO_HOOKS <<<"$raw"
}

mkinitcpio_has_hook() {
    local want="$1" h
    for h in "${MKINITCPIO_HOOKS[@]}"; do
        [ "$h" = "$want" ] && return 0
    done
    return 1
}

plymouth_hooks_write() {
    local -a out=()
    local h placed=0
    mkinitcpio_has_hook plymouth && placed=1
    for h in "${MKINITCPIO_HOOKS[@]}"; do
        out+=("$h")
        if [ "$placed" = 0 ] && { [ "$h" = systemd ] || [ "$h" = udev ]; }; then
            out+=(plymouth)
            placed=1
        fi
    done
    if [ "$placed" = 0 ]; then
        out=(plymouth "${out[@]}")
    fi

    sudo cp -n "$MKINITCPIO_CONF" "$MKINITCPIO_CONF.sauce-bak" 2>/dev/null || true
    sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)[[:space:]]*$|HOOKS=(${out[*]})|" "$MKINITCPIO_CONF" \
        || { log_error "could not update HOOKS in $MKINITCPIO_CONF."; return 1; }
    log_info "HOOKS=(${out[*]})"
}

plymouth_cmdline_flags() {
    local out="$1" flag
    for flag in quiet splash; do
        case " $out " in
            *" $flag "*) ;;
            *) out="${out:+$out }$flag" ;;
        esac
    done
    printf '%s' "$out"
}

plymouth_cmdline_write() {
    local touched=0 found=0

    if [ -f /etc/kernel/cmdline ]; then
        found=1
        local cur new
        cur="$(tr '\n' ' ' </etc/kernel/cmdline | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
        new="$(plymouth_cmdline_flags "$cur")"
        if [ "$new" != "$cur" ]; then
            printf '%s\n' "$new" | sudo tee /etc/kernel/cmdline >/dev/null \
                || { log_error "could not write /etc/kernel/cmdline."; return 1; }
            log_info "added quiet/splash to /etc/kernel/cmdline"
            touched=1
        fi
    fi

    local -a entries=()
    mapfile -t entries < <(sudo find /boot/loader/entries -maxdepth 1 -name '*.conf' 2>/dev/null)
    local entry
    for entry in "${entries[@]}"; do
        sudo grep -qE '^options ' "$entry" || continue
        found=1
        sudo grep -qE '^options .*(^| )splash( |$)' "$entry" && continue
        sudo grep -qE '^options .*(^| )quiet( |$)' "$entry" \
            || sudo sed -i -E 's/^(options .*)$/\1 quiet/' "$entry"
        sudo sed -i -E 's/^(options .*)$/\1 splash/' "$entry" \
            || { log_error "could not add splash to $entry."; return 1; }
        log_info "added quiet/splash to $entry"
        touched=1
    done

    if [ "$found" = 0 ]; then
        log_warn "no /etc/kernel/cmdline or systemd-boot entries found; add 'quiet splash' to your kernel command line yourself or the splash stays in text mode."
    fi
    [ "$touched" = 1 ]
}

plymouth_is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] && return 0
    grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

setup_plymouth() {
    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" != arch ]; then
        log_info "The Plymouth step drives mkinitcpio hooks — skipping on $family."
        return 0
    fi
    if plymouth_is_wsl; then
        log_info "WSL has no boot splash of its own — skipping Plymouth."
        return 0
    fi
    if [ "${PLYMOUTH:-1}" = 0 ]; then
        log_info "PLYMOUTH=0 — leaving the boot splash alone."
        return 0
    fi
    if [ ! -f "$MKINITCPIO_CONF" ]; then
        log_info "No $MKINITCPIO_CONF on this host — skipping the Plymouth boot splash."
        return 0
    fi
    if ! command -v mkinitcpio >/dev/null 2>&1; then
        log_info "mkinitcpio is not installed here — skipping the Plymouth boot splash."
        return 0
    fi
    if ! mkinitcpio_hooks_read; then
        log_warn "could not read a HOOKS=(...) line from $MKINITCPIO_CONF; skipping Plymouth."
        return 0
    fi

    if ! pacman -Qq plymouth >/dev/null 2>&1; then
        log_install "Installing Plymouth for a graphical boot splash and LUKS passphrase prompt..."
        install_pkgs plymouth || { log_error "plymouth install failed."; return 1; }
    fi

    local changed=0
    local theme="${PLYMOUTH_THEME:-arch}"
    if plymouth_theme_is_sauce "$theme" && ! plymouth_theme_is_current "$theme"; then
        plymouth_theme_install "$theme" && changed=1
    fi
    if ! plymouth-set-default-theme -l 2>/dev/null | grep -qx "$theme"; then
        install_pkgs "plymouth-theme-$theme" >/dev/null 2>&1 || true
        if ! plymouth-set-default-theme -l 2>/dev/null | grep -qx "$theme"; then
            log_warn "Plymouth theme '$theme' is not installed — falling back to spinner."
            theme=spinner
        fi
    fi

    mkinitcpio_has_hook kms \
        || log_warn "the kms hook is missing from HOOKS; without early KMS the splash drops to text mode."
    if ! mkinitcpio_has_hook encrypt && ! mkinitcpio_has_hook sd-encrypt; then
        log_info "No encrypt hook in HOOKS — this host gets the splash only, with no passphrase prompt to theme."
    fi

    if mkinitcpio_has_hook plymouth; then
        log_info "mkinitcpio already has the plymouth hook."
    else
        log_install "Adding the plymouth hook to $MKINITCPIO_CONF ahead of the encrypt hook..."
        plymouth_hooks_write || return 1
        changed=1
    fi

    plymouth_cmdline_write && changed=1

    local current
    current="$(plymouth-set-default-theme 2>/dev/null || true)"
    [ "$current" = "$theme" ] || changed=1

    if [ "$changed" = 0 ]; then
        log_info "Plymouth is already configured with the $theme theme."
        return 0
    fi

    log_install "Setting the Plymouth theme to $theme and rebuilding the initramfs..."
    sudo plymouth-set-default-theme -R "$theme" \
        || { log_error "plymouth-set-default-theme failed; fix the error and run 'sudo mkinitcpio -P'."; return 1; }

    log_done "Plymouth is set up; the graphical splash and passphrase prompt appear on the next boot."
    log_hint "Press Esc at the prompt for the text view when you need to read cryptsetup errors."
    log_hint "The theme comes from the plymouthTheme prompt (SAUCE_PLYMOUTH_THEME seeds it); PLYMOUTH_THEME overrides it for one run and PLYMOUTH=0 skips the step. $MKINITCPIO_CONF.sauce-bak holds the pre-change HOOKS."
}

setup_wifi_powersave() {
    if [ "${WIFI_POWERSAVE:-1}" = 0 ]; then
        log_info "WIFI_POWERSAVE=0 — leaving Wi-Fi power management alone."
        return 0
    fi
    if ! command -v nmcli >/dev/null 2>&1; then
        log_info "NetworkManager is not in use here — skipping the Wi-Fi power-save fix."
        return 0
    fi
    if ! lsmod 2>/dev/null | grep -q '^iwlwifi'; then
        log_info "No Intel iwlwifi adapter loaded — skipping the Wi-Fi power-save fix."
        return 0
    fi

    local conf=/etc/NetworkManager/conf.d/00-sauce-wifi-powersave.conf
    if [ -f "$conf" ] && grep -q 'managed by sauce' "$conf" 2>/dev/null; then
        log_info "Wi-Fi power save is already disabled by sauce."
        return 0
    fi

    require_sudo || return 1

    log_install "Disabling Wi-Fi power save to stop iwlwifi beacon-loss disconnects..."
    sudo install -d -m 0755 /etc/NetworkManager/conf.d \
        || { log_error "could not create /etc/NetworkManager/conf.d."; return 1; }
    printf '%s\n' \
        '# managed by sauce' \
        '[connection]' \
        'wifi.powersave = 2' \
        | sudo tee "$conf" >/dev/null \
        || { log_error "could not write $conf."; return 1; }

    sudo nmcli general reload conf >/dev/null 2>&1 || sudo systemctl reload NetworkManager >/dev/null 2>&1 || true

    local dev
    dev="$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
    if [ -n "$dev" ] && command -v iw >/dev/null 2>&1; then
        sudo iw dev "$dev" set power_save off >/dev/null 2>&1 || true
    fi

    log_done "Wi-Fi power save is off; reconnect (or reboot) for it to take effect on the active link."
    log_hint "Costs a little idle battery. Set WIFI_POWERSAVE=0 and delete $conf to revert."
}

case "${1:-all}" in
    base-packages) setup_base_packages ;;
    paru)          setup_paru ;;
    default-kernel) setup_default_kernel ;;
    plymouth)      setup_plymouth ;;
    console-font)  setup_console_font ;;
    wifi-powersave) setup_wifi_powersave ;;
    nvidia)        setup_nvidia ;;
    clamav)        setup_clamav ;;
    rslsync)       setup_rslsync ;;
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
        setup_default_kernel
        setup_plymouth
        setup_wifi_powersave
        setup_nvidia
        setup_clamav
        setup_rslsync
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
