# ~/.config/fish/config.fish — managed by chezmoi (source: ~/.sauce).
# Edit via `chezmoi edit ~/.config/fish/config.fish`.

set -g red (printf '\e[0;31m')
set -g green (printf '\e[0;32m')
set -g yellow (printf '\e[0;33m')
set -g blue (printf '\e[0;34m')
set -g magenta (printf '\e[0;35m')
set -g cyan (printf '\e[0;36m')
set -g clear (printf '\e[0m')
set -g bold (printf '\e[0;1m')
set -g dim (printf '\e[0;2m')
set -g uparrow ↑
set -g rightarrow →
set -g dash –
set -g x ✗
set -g line "─────────────────────────────────────────────────────"

set -g dateColor $cyan
set -g nameColor $blue

# docker
function LIST_DOCKER_CONTAINERS
    for container_status in Up Running Restarting Created Paused Exited Stopped Dead
        set -l display_status
        switch $container_status
            case Up Running
                set display_status "$green$uparrow$clear"
            case Exited Stopped
                set display_status "$yellow$dash$clear"
            case Dead
                set display_status "$red$x$clear"
            case '*'
                set display_status $container_status
        end
        set -l group ''
        for ps_result in (docker ps -a --format "{{.Status}} | {{.Names}} | {{.Image}} | {{.Ports}}" | grep "$container_status ")
            set -l container ''
            set -l fields (string split '|' -- $ps_result)
            for i in (seq (count $fields))
                set -l field (string trim -- $fields[$i])
                test -z "$field"; and continue
                if test $i -eq 1
                    continue
                else if test $i -eq 2
                    set container "$container$display_status $bold$field$clear"\n
                else
                    set container "$container"\t"$dim$field"\n
                end
            end
            set group "$group$container"
        end
        test -n "$group"; and printf '%s' "$group"
    end
end

# distro-aware system upgrade (mirrors the `update` alias in the other shells)
function update
    if command -q apt
        sudo apt update; and sudo apt upgrade -y; and sudo apt dist-upgrade -y; and sudo snap refresh
    else if command -q pacman
        sudo pacman -Syu; and paru -Syu
    else if command -q dnf
        sudo dnf upgrade -y
    end
    command -q flatpak; and flatpak update --user -y
end

# print header (interactive only)
if status is-interactive
    set -l date (date +'%A, %b %d, %Y')
    set -l allips (ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    set -l ipslines
    for ip in $allips
        echo $ip
        if string match -q '127*' -- $ip; or string match -q '172*' -- $ip
            continue
        end
        if string match -q '10.*' -- $ip
            set -a ipslines ' LAN:        '"$dateColor$ip$nameColor"
        end
        if string match -q '100.*' -- $ip
            set -a ipslines ' tailnet:    '"$dateColor$ip$nameColor"
        end
    end
    set -l host (figlet -f smslant "@"(hostname) | sed 's/^/ /')
    clear
    echo ' '"$yellow$line$clear"
    echo "$nameColor$host$clear"
    echo ''
    echo ' '"$dateColor$date$clear"
    echo ' '"$nameColor"(whoami)'@'(hostname)"$clear"
    echo ''
    for il in $ipslines
        echo "$nameColor$il$clear"
    end
    echo ' '"$yellow$line$clear"
    echo ''
    echo ' '"$nameColor"'across the universe divide...'"$clear"
    echo ''
    echo '           BP55555P#'
    echo '        #'"$cyan"'G55PGGGGGP'"$clear"'?PB&'
    echo '      B'"$cyan"'55PGGGGGGGGG'"$clear"'J'"$cyan"'GPPG'"$clear"'#'
    echo '    &'"$cyan"'Y5PGGGGGGGGGP'"$clear"'Y'"$cyan"'PBBBG5'"$clear"'P'
    echo '    #'"$cyan"'JGGGGGGGGGP'"$clear"'YY'"$cyan"'GBBBBBBY'"$clear"'B'
    echo '    B'"$cyan"'JGGGGGGGP'"$clear"'55'"$cyan"'GBBBBBBBBY'"$clear"'&'
    echo '    B'"$cyan"'YGGGGGG'"$clear"'JJ'"$cyan"'PGBBBBBBBG5'"$clear"'#'
    echo '    B'"$cyan"'YGGGGGG'"$clear"'JBGP'"$cyan"'5PGGBG5G'"$clear"'&'
    echo '    G'"$cyan"'YGGGGGG'"$clear"'JB'"$blue"'##'"$clear"'BBG'"$cyan"'PY5'"$clear"'#'
    echo '    G'"$cyan"'YGGGGGP'"$clear"'?G'"$blue"'######'"$clear"'BGPP'
    echo '    G'"$cyan"'YGGP'"$clear"'55PGGPPG'"$blue"'B######'"$clear"'5G'
    echo '    P'"$cyan"'YP'"$clear"'5P'"$blue"'B#&&&#'"$clear"'BGPPG'"$blue"'B###'"$clear"'PG'
    echo '    BJP'"$blue"'B&&&&&#&&&&#'"$clear"'BGPP'"$blue"'B'"$clear"'5G'
    echo '      &BGGG'"$blue"'B#&&&&#&&&#'"$clear"'B5J#'
    echo '          #BGG'"$blue"'BB#&#'"$clear"'BGGB#'
    echo '             &#BGPGB&'
    echo ''
    echo ' '"$yellow$line$clear"
end

# aliases
alias docker-containers 'LIST_DOCKER_CONTAINERS'
alias sauce 'chezmoi apply'                # re-apply dotfiles + run install/update scripts
alias sauce-edit 'chezmoi edit --apply'    # edit a managed file and apply on save
alias sauce-cd 'chezmoi cd'                # drop into the ~/.sauce source repo

# aliases generated from ~/.sauce/scripts/*.sh (setup, onchange, update-*, update-all)
if test -d ~/.sauce/scripts
    for _script in ~/.sauce/scripts/*.sh
        test -e $_script; or continue
        alias (basename $_script .sh) "bash $_script"
    end
end

# tooling env/PATH — one runtime-guarded block per tool (a no-op if absent).
# Managed by chezmoi; keep in sync when adding a tool.
# dotnet
set -gx DOTNET_ROOT "$HOME/.dotnet"
if test -d "$DOTNET_ROOT"
    fish_add_path -a "$DOTNET_ROOT" "$DOTNET_ROOT/tools"
end
# gcloud
test -d "$HOME/google-cloud-sdk/bin"; and fish_add_path "$HOME/google-cloud-sdk/bin"
# Go
fish_add_path -a /usr/local/go/bin $HOME/go/bin
# lm studio cli
test -d "$HOME/.lmstudio/bin"; and fish_add_path -a "$HOME/.lmstudio/bin"
# Neovim (latest, installed to ~/.apps/nvim) — prepended so it wins over the distro package
test -d "$HOME/.apps/nvim/bin"; and fish_add_path -p "$HOME/.apps/nvim/bin"
set -gx EDITOR nvim
set -gx VISUAL nvim
alias vi 'nvim'
alias vim 'nvim'
# nvm — nvm.sh is bash/zsh only; for fish install e.g. jorgebucaran/nvm.fish
set -gx NVM_DIR "$HOME/.nvm"
# opencode
test -d "$HOME/.opencode/bin"; and fish_add_path "$HOME/.opencode/bin"
# pyenv
set -gx PYENV_ROOT "$HOME/.pyenv"
if test -d "$PYENV_ROOT"
    fish_add_path "$PYENV_ROOT/bin"
    pyenv init - fish | source
end

# path
test -d "$HOME/.local/bin"; and fish_add_path "$HOME/.local/bin"
test -d "$HOME/.apps"; and fish_add_path "$HOME/.apps"

# prompt
if type -q oh-my-posh
    oh-my-posh init fish --config ~/.config/oh-my-posh/sauce.toml | source
end

# your personal tweaks — kept in ~/.config/fish/user.fish (created once, never touched by chezmoi)
test -f ~/.config/fish/user.fish; and source ~/.config/fish/user.fish
