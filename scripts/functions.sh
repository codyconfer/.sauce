#! /bin/bash

source "$HOME/.sauce/scripts/lib/styles.sh"

_sauce_tool_registered() {
    command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
    chezmoi data --format json 2>/dev/null \
        | jq -e --arg t "$1" '(.tools // []) | index($t)' >/dev/null 2>&1
}

get_secret() {
    local item="${1:-}" field="${2:-password}" value=""

    if [ -z "$item" ]; then
        echo "usage: get_secret <item> [field]" >&2
        return 2
    fi

    if _sauce_tool_registered bitwarden-cli && command -v bw >/dev/null 2>&1; then
        value=$(bw get "$field" "$item" 2>/dev/null) || value=""
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

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

get_ips() {
    local allips ip ips=""
    if command -v ip >/dev/null 2>&1; then
        allips=($(ip -4 addr | grep -oE 'inet [0-9]+(\.[0-9]+){3}' | awk '{print $2}'))
    else
        allips=($(ifconfig 2>/dev/null | grep -oE 'inet [0-9]+(\.[0-9]+){3}' | awk '{print $2}'))
    fi
    for ip in "${allips[@]}"; do
        if [[ $ip != 127* ]] && [[ $ip != 172* ]]; then
            if [[ $ip == 10.* ]]; then
                ips="${ips}LAN:        ${cyan}${ip}${blue}"${linebreak}
            fi
        fi
    done
    if command -v tailscale >/dev/null 2>&1; then
        tailnet_domain=$(tailscale whois $(tailscale ip --4) | grep -o -P "$(hostname).*.ts.net")
        ips="${ips}tailnet:    ${cyan}$(tailscale ip --4) ${blue}"${linebreak}
        ips="${ips}            ${tailnet_domain}"${linebreak}
    fi

    printf '%s' "$ips"
}

print_ips() {
    get_ips
}

_sauce_print_header() {
    local dateColor=$cyan
    local nameColor=$blue
    local date
    date=$(date +'%A, %b %d, %Y')
    local host
    host=$(figlet -f smslant "@$(hostname)" | sed "s/^/$(printf '%*s' "1" '')/")
    clear
    cat <<-_END_
${yellow}${line}${clear}
${nameColor}${host}${clear}${linebreak}
_END_
    cat <<-_END_ | sed "s/^/$(printf '%*s' "2" '')/"
${dateColor}${date}${clear}
${nameColor}$(whoami)@$(hostname)${clear}${linebreak}
${nameColor}$(get_ips)${clear}${linebreak}
_END_
    cat <<-_END_
${yellow}${line}${clear}${linebreak}
$(pretty_lights 3)${linebreak}
${yellow}${line}${clear}${linebreak}
_END_
}

list_docker_containers() {
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
                    :
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

alias docker-containers=$(list_docker_containers)
alias sauce="chezmoi apply"
alias sauce-edit="chezmoi edit --apply"
alias sauce-cd="chezmoi cd"
