# PROFILE Cody Confer

# functions
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
downarrow='\u2193'
leftarrow='\u2190'
dash='\u229d'
star='\u229b'
slash='\u2298'
x='\u2297'
line=" \e[38;5;154m─────────────────────────────────────────────────────\e[0m"

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
                    # omit first query field from output
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

# alias
alias docker-containers=LIST_DOCKER_CONTAINERS

# exports
export PATH=/usr/bin:/boot/dietpi:/bin:/usr/sbin:/sbin:$PATH
export ZSH="$HOME/.oh-my-zsh"
export DOTNET_ROOT=/opt/dotnet

# zsh config
ZSH_THEME="afowler"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy.mm.dd"
plugins=(colorize docker git history themes z)

# init scripts
source $ZSH/oh-my-zsh.sh
/boot/dietpi/dietpi-login

# print message
figlet -f smslant "@$(hostname)"
echo
echo $line
echo
docker-containers
