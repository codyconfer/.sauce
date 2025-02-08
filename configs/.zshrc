# ~/.zshrc
# 
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
line="─────────────────────────────────────────────────────"

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

# aliases
alias docker-containers=LIST_DOCKER_CONTAINERS

export PATH=$PATH:/home/codyconfer/.local/bin
eval "$(oh-my-posh init zsh --config /home/codyconfer/.sauce/themes/ohmyposh-sauce.toml)"

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

fpath+=~/.zfunc
autoload -Uz compinit && compinit

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# print header
dateColor=$cyan
nameColor=$blue
date=$(date +'%A, %b %d, %Y')

heading=$(cat <<-_END_
 ${yellow}${line}${clear}
 ${dateColor}${date}${clear}
 ${nameColor}$(whoami)@$(hostname)${clear}

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
echo ${heading}
docker-containers
