# ~/.zshrc
# 
# config
tailnetname=wampus-galaxy.ts.net
##
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

# print header
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
ips="${ips} tailnet:    ${dateColor}$(hostname).${tailnetname}${nameColor}\n"
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
    echo "refreshing zsh..."
    rm ~/.zshrc
    cp ~/.sauce/configs/.zshrc ~/.zshrc
    chsh -s $(which zsh)
    echo " --- "
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
alias zshrc=refresh_profile

export PATH=$PATH:/home/codyconfer/.local/bin
eval "$(oh-my-posh init zsh --config /home/codyconfer/.sauce/themes/sauce.ohmyposh.toml)"

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

fpath+=~/.zfunc
autoload -Uz compinit && compinit

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
