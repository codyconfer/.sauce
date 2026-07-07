red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m'
bold='\033[0;1m'
dim='\033[0;2m'
italic='\033[0;3m'
underline='\033[0;4m'
blinking='\033[0;5m'
reverse='\033[0;7m'
invisible='\033[8m'
uparrow='\u2191'
rightarrow='\u2192'
dash='\u2013'
x='\u2717'
line="─────────────────────────────────────────────────────"

dateColor=$cyan
nameColor=$blue
date=$(date +'%A, %b %d, %Y')

allips=($(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}'))
ips=""
for ip in "${allips[@]}"; do
    echo $ip
    if [[ $ip != 127* ]] && [[ $ip != 172* ]]; then
        if [[ $ip == 10.* ]]; then
            ips="${ips} LAN:        ${dateColor}${ip}${nameColor}\n"
        fi
        if [[ $ip == 100.* ]]; then
            ips="${ips} tailnet:    ${dateColor}${ip}${nameColor}\n"
        fi
    fi
done
host=$(figlet -f smslant "@$(hostname)" | sed 's/^/ /')
heading=$(cat <<-_END_
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
)
clear
echo ${heading}

function refresh_profile() {
    echo "reloading zsh..."
    exec zsh
}

function reset_profile() {
    echo "resetting zsh to default (clears personal tweaks)..."
    bash ~/.sauce/scripts/stow.sh restow
    printf '%s\n' "# add your personal zsh tweaks here" > ~/.config/sauce/user.sh
    exec zsh
}

function LIST_DOCKER_CONTAINERS() {
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

alias docker-containers=LIST_DOCKER_CONTAINERS
alias zshrc=refresh_profile
alias zshrc-reset=reset_profile
alias sauce-stow="bash ~/.sauce/scripts/stow.sh"
alias nvimrc="bash ~/.sauce/scripts/build-nvim.sh"
alias nvimrc-reset="bash ~/.sauce/scripts/reset-nvim.sh"
alias update='(command -v apt > /dev/null \
    && sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo snap refresh) \
    || (command -v pacman > /dev/null \
    && sudo pacman -Syu && paru -Syu) \
    || (command -v dnf > /dev/null \
    && sudo dnf upgrade -y); \
    command -v flatpak > /dev/null && flatpak update --user -y'

for _script in ~/.sauce/scripts/update-*.sh ~/.sauce/scripts/install-*.sh; do
    [ -e "$_script" ] || continue
    alias "$(basename "$_script" .sh)"="bash $_script"
done
unset _script

if [ -d "$HOME/.config/sauce/profile.d/posix" ]; then
    for _frag in "$HOME/.config/sauce/profile.d/posix"/*.sh(N); do
        [ -r "$_frag" ] && source "$_frag"
    done
    unset _frag
fi

LOCAL_BIN="$HOME/.local/bin"
APPS="$HOME/.apps"
if [ -d "$LOCAL_BIN" ]; then
    export PATH="$PATH:$LOCAL_BIN"
fi
if [ -d "$APPS" ]; then
    export PATH="$PATH:$APPS"
fi

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY

setopt AUTO_MENU COMPLETE_IN_WORD ALWAYS_TO_END
fpath+=(~/.zfunc)
mkdir -p ~/.cache/zsh 2>/dev/null
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%F{blue}%d%f%b'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/zcompcache

if command -v dotnet >/dev/null 2>&1; then
    _dotnet_zsh_complete() {
        local completions=("$(dotnet complete "$words")")
        if [ -z "$completions" ]; then
            _arguments '*::arguments: _normal'
            return
        fi
        _values = "${(ps:\n:)completions}"
    }
    compdef _dotnet_zsh_complete dotnet
fi

eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/sauce.toml)"

[ -r "$HOME/.config/sauce/user.sh" ] && source "$HOME/.config/sauce/user.sh"

[ -f "$HOME/.zsh/plugins.zsh" ] && source "$HOME/.zsh/plugins.zsh"
