#! /bin/bash

# ~/.sauce/scripts/functions.sh — shared interactive shell functions.
#
# Sourced (not aliased) by dot_zshrc / dot_bashrc; bash & zsh compatible. Kept
# self-contained on purpose — it runs in every interactive shell, so it does NOT
# source lib/common.sh (which would pull in distro detection and a pile of
# installer helpers we don't want at prompt time).

# _sauce_tool_registered <tool> — true if <tool> is in chezmoi's selected `.tools`.
# Mirrors the `chezmoi data` idiom in scripts/lib/runner.sh. When chezmoi or jq
# aren't available we return true so callers fall back to plain `command -v`
# detection (keeps these helpers usable on non-chezmoi machines).
_sauce_tool_registered() {
    command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
    chezmoi data --format json 2>/dev/null \
        | jq -e --arg t "$1" '(.tools // []) | index($t)' >/dev/null 2>&1
}

# get_secret <item> [field] — print a secret to stdout, trying Bitwarden then 1Password.
#
# Order: if bitwarden-cli is registered in chezmoi and `bw` is installed, try
# `bw` first; on a miss, fall through to `op` (1password-cli); error if neither
# yields the secret. `field` defaults to `password`. Field semantics differ
# slightly between backends: for `bw` it's the object (password|username|totp|
# notes|uri|...), for `op` it's the field label — `password` works in both.
#
#   PASSWORD=$(get_secret "GitHub")
#   TOKEN=$(get_secret "My API" credential)
get_secret() {
    local item="${1:-}" field="${2:-password}" value=""

    if [ -z "$item" ]; then
        echo "usage: get_secret <item> [field]" >&2
        return 2
    fi

    # Bitwarden
    if _sauce_tool_registered bitwarden-cli && command -v bw >/dev/null 2>&1; then
        value=$(bw get "$field" "$item" 2>/dev/null) || value=""
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

    # 1Password
    if _sauce_tool_registered 1password-cli && command -v op >/dev/null 2>&1; then
        value=$(op item get "$item" --fields "$field" --reveal 2>/dev/null) || value=""
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

    echo "get_secret: secret '$item' (field '$field') not found in Bitwarden or 1Password" >&2
    return 1
}

red=$'\033[0;31m'
green=$'\033[0;32m'
yellow=$'\033[0;33m'
blue=$'\033[0;34m'
magenta=$'\033[0;35m'
cyan=$'\033[0;36m'
clear=$'\033[0m'
bold=$'\033[0;1m'
dim=$'\033[0;2m'
italic=$'\033[0;3m'
underline=$'\033[0;4m'
blinking=$'\033[0;5m'
reverse=$'\033[0;7m'
invisible=$'\033[8m'
uparrow=$'↑'
rightarrow=$'→'
dash=$'–'
x=$'✗'
line="─────────────────────────────────────────────────────"

_sauce_print_header() {
    local dateColor=$cyan
    local nameColor=$blue
    local date
    date=$(date +'%A, %b %d, %Y')

    local allips ip ips=""
    if command -v ip >/dev/null 2>&1; then
        allips=($(ip -4 addr | grep -oE 'inet [0-9]+(\.[0-9]+){3}' | awk '{print $2}'))
    else
        allips=($(ifconfig 2>/dev/null | grep -oE 'inet [0-9]+(\.[0-9]+){3}' | awk '{print $2}'))
    fi
    for ip in "${allips[@]}"; do
        if [[ $ip != 127* ]] && [[ $ip != 172* ]]; then
            if [[ $ip == 10.* ]]; then
                ips="${ips} LAN:        ${dateColor}${ip}${nameColor}"$'\n'
            fi
            if [[ $ip == 100.* ]]; then
                ips="${ips} tailnet:    ${dateColor}${ip}${nameColor}"$'\n'
            fi
        fi
    done

    local host
    host=$(figlet -f smslant "@$(hostname)" | sed 's/^/ /')
    clear
    cat <<-_END_
	 ${yellow}${line}${clear}
	${nameColor}${host}${clear}

	 ${dateColor}${date}${clear}
	 ${nameColor}$(whoami)@$(hostname)${clear}

	${nameColor}${ips}${clear}
	 ${yellow}${line}${clear}

	 ${nameColor}across the universe divide...${clear}

	           BP55555P#
	        #${cyan}G55PGGGGGP${clear}?PB&
	      B${cyan}55PGGGGGGGGG${clear}J${cyan}GPPG${clear}#
	    &${cyan}Y5PGGGGGGGGGP${clear}Y${cyan}PBBBG5${clear}P
	    #${cyan}JGGGGGGGGGP${clear}YY${cyan}GBBBBBBY${clear}B
	    B${cyan}JGGGGGGGP${clear}55${cyan}GBBBBBBBBY${clear}&
	    B${cyan}YGGGGGG${clear}JJ${cyan}PGBBBBBBBG5${clear}#
	    B${cyan}YGGGGGG${clear}JBGP${cyan}5PGGBG5G${clear}&
	    G${cyan}YGGGGGG${clear}JB${blue}##${clear}BBG${cyan}PY5${clear}#
	    G${cyan}YGGGGGP${clear}?G${blue}######${clear}BGPP
	    G${cyan}YGGP${clear}55PGGPPG${blue}B######${clear}5G
	    P${cyan}YP${clear}5P${blue}B#&&&#${clear}BGPPG${blue}B###${clear}PG
	    BJP${blue}B&&&&&#&&&&#${clear}BGPP${blue}B${clear}5G
	      &BGGG${blue}B#&&&&#&&&#${clear}B5J#
	          #BGG${blue}BB#&#${clear}BGGB#
	             &#BGPGB&

	 ${yellow}${line}${clear}
	_END_
}

LIST_DOCKER_CONTAINERS() {
    local tmp_ifs=$IFS
    IFS=$'\n'
    local container=""; local group=""
    for container_status in 'Up' 'Running' 'Restarting' 'Created' 'Paused' 'Exited' 'Stopped' 'Dead'; do
        group=""
        local container=""; local ps_result=""; local display_status=""
        case $container_status in
            Up)
                display_status="${green}${uparrow}${clear}"
                ;;
            Running)
                display_status="${green}${uparrow}${clear}"
                ;;
            Exited)
                display_status="${yellow}${dash}${clear}"
                ;;
            Stopped)
                display_status="${yellow}${dash}${clear}"
                ;;
            Dead)
                display_status="${red}${x}${clear}"
                ;;
            *)
                display_status=$container_status
                ;;
        esac
        for ps_result in $(docker ps -a --format "{{.Status}} | {{.Names}} | {{.Image}} | {{.Ports}}" | grep "${container_status} "); do
            container=""
            i=1
            while iter=$(echo "$ps_result" | cut -d\| -f$i | xargs) ; [ -n "$iter" ] ; do
                if [[ $i == 1 ]]; then
                    : # omit first query field from output
                elif [[ $i == 2 ]]; then
                    container="${container}${display_status} ${bold}${iter}${clear}\n"
                else
                    container="${container}\t${dim}${iter}\n"
                fi
                i=$((i+1))
            done
            group="${group}${container}"
        done
        if [[ $group != "" ]]; then
            echo -e "${group}"
        fi
    done
    IFS=$tmp_ifs
}

update() {
    if [ "$(uname -s)" = Darwin ]; then
        brew update && brew upgrade && brew upgrade --cask
        return
    fi
    (command -v apt > /dev/null \
        && sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo snap refresh) \
        || (command -v pacman > /dev/null \
        && sudo pacman -Syu && paru -Syu) \
        || (command -v dnf > /dev/null \
        && sudo dnf upgrade -y)
    command -v flatpak > /dev/null && flatpak update --user -y
}

alias docker-containers=LIST_DOCKER_CONTAINERS
alias sauce="chezmoi apply"                 # re-apply dotfiles + run install/update scripts
alias sauce-edit="chezmoi edit --apply"     # edit a managed file and apply on save
alias sauce-cd="chezmoi cd"                 # drop into the ~/.sauce source repo
