# configs -------------------------------------------------------------------------
set -gx DOTNET_ROOT "$HOME/.dotnet"
set -gx PYENV_ROOT "$HOME/.pyenv"
set -gx NVM_DIR "$HOME/.nvm"
set -q OLLAMA_HOST; or set -gx OLLAMA_HOST 127.0.0.1:11434
set -g USR /usr/local
set -g OPT /opt
set -g PATH_DIRS \
    $OPT/bin \
    $USR/bin \
    $USR/go/bin \
    $HOME/.local/bin \
    $HOME/go/bin \
    $PYENV_ROOT/bin \
    $DOTNET_ROOT \
    $DOTNET_ROOT/tools \
    $HOME/.cargo/bin \
    $HOME/.lmstudio/bin \
    $HOME/.opencode/bin \
    $HOME/google-cloud-sdk/bin \
    $HOME/.local/share/flatpak/exports/bin \
    /var/lib/flatpak/exports/bin
set -g RCs \
    ~/.config/fish/dev.fish \
    ~/.config/fish/ops.fish \
    ~/.config/fish/yggdrasil.fish \
    ~/.config/fish/user.fish \
    ~/.config/fish/local.fish
set -g SAUCE_DIR "$HOME/.sauce"
set -g THEME_DIR "$HOME/.config/oh-my-posh"
status is-interactive; and echo "🐟⧗...loading ~/.config/fish/config.fish"

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
set -g oil 🝆
set -g pad '  '
set -g line "─────────────────────────────────────────────────────"

set -g dateColor $cyan
set -g nameColor $blue
# path handler --------------------------------------------------------------------
for dir in $PATH_DIRS
    test -d $dir; and fish_add_path -g -a $dir
end
# editor config -------------------------------------------------------------------
set -gx EDITOR nvim
set -gx VISUAL nvim
alias vi 'nvim'
alias vim 'nvim'
# dev env setup --------------------------------------------------------------------
function _sauce_nvm_default_dir --description 'resolve the nvm default alias to a version dir'
    set -l root "$NVM_DIR/versions/node"
    test -d "$root"; or return 1
    set -l want
    test -f "$NVM_DIR/alias/default"; and set want (string trim -- (cat "$NVM_DIR/alias/default"))
    for i in 1 2 3
        if test -n "$want"; and test -f "$NVM_DIR/alias/$want"
            set want (string trim -- (cat "$NVM_DIR/alias/$want"))
        else
            break
        end
    end
    if test -n "$want"; and test -d "$root/$want"
        echo "$root/$want"
        return 0
    end
    set -l newest (ls -1 "$root" 2>/dev/null | sort -V | tail -n1)
    test -n "$newest"; or return 1
    echo "$root/$newest"
end

set -l _nvm_dir (_sauce_nvm_default_dir)
test -n "$_nvm_dir"; and fish_add_path -g -p "$_nvm_dir/bin"

test -d "$PYENV_ROOT"; and command -q pyenv; and pyenv init - fish | source
# homebrew setup if macos ----------------------------------------------------------
if test (uname) = Darwin
    for _brew in $OPT/homebrew/bin/brew $USR/bin/brew
        if test -x $_brew
            eval ($_brew shellenv)
            break
        end
    end
    set -e _brew
end
if not command -q prime-run
    function prime-run --description 'run a command on the NVIDIA GPU via PRIME offload'
        __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only \
            __GLX_VENDOR_LIBRARY_NAME=nvidia $argv
    end
end

# .sauce script handlers -----------------------------------------------------------
function _sauce_tool_registered
    if not command -q chezmoi; or not command -q jq
        return 0
    end
    chezmoi data --format json 2>/dev/null \
        | jq -e --arg t "$argv[1]" '(.tools // []) | index($t)' >/dev/null 2>&1
end

function get_secret
    set -l item $argv[1]
    set -l field password
    test (count $argv) -ge 2; and set field $argv[2]

    if test -z "$item"
        echo "usage: get_secret <item> [field]" >&2
        return 2
    end

    if _sauce_tool_registered bitwarden-cli; and command -q bw
        set -l value (bw get $field $item 2>/dev/null)
        if test -n "$value"
            printf '%s\n' $value
            return 0
        end
    end

    if _sauce_tool_registered 1password-cli; and command -q op
        set -l value (op item get $item --fields $field --reveal 2>/dev/null)
        if test -n "$value"
            printf '%s\n' $value
            return 0
        end
    end

    echo "get_secret: secret '$item' (field '$field') not found in Bitwarden or 1Password" >&2
    return 1
end

function get_ips
    set -l allips
    if command -q ip
        set allips (ip -4 addr | grep -oE 'inet [0-9]+(\.[0-9]+){3}' | awk '{print $2}')
    else
        set allips (ifconfig 2>/dev/null | grep -oE 'inet [0-9]+(\.[0-9]+){3}' | awk '{print $2}')
    end
    for ip in $allips
        if string match -q '127*' -- $ip; or string match -q '172*' -- $ip
            continue
        end
        if string match -q '10.*' -- $ip
            printf '%s\n' "LAN:        $cyan$ip$blue"
        end
    end
    if command -q tailscale
        set -l ts_ip (tailscale ip --4 2>/dev/null | head -n1)
        if test -n "$ts_ip"
            set -l ts_domain (tailscale whois "$ts_ip" 2>/dev/null \
                | grep -oE (hostname)'[^[:space:]]*\.ts\.net' | head -n1)
            printf '%s\n' "tailnet:    $cyan$ts_ip $blue"
            test -n "$ts_domain"; and printf '%s\n' "            $ts_domain"
        end
    end
end

function print_ips
    get_ips
end

function pretty_lights
    echo '         BP55555P#'
    echo '       #'"$cyan"'G55PGGGGGP'"$clear"'?PB&'
    echo '     B'"$cyan"'55PGGGGGGGGG'"$clear"'J'"$cyan"'GPPG'"$clear"'#'
    echo '   &'"$cyan"'Y5PGGGGGGGGGP'"$clear"'Y'"$cyan"'PBBBG5'"$clear"'P'
    echo '   #'"$cyan"'JGGGGGGGGGP'"$clear"'YY'"$cyan"'GBBBBBBY'"$clear"'B'
    echo '   B'"$cyan"'JGGGGGGGP'"$clear"'55'"$cyan"'GBBBBBBBBY'"$clear"'&'
    echo '   B'"$cyan"'YGGGGGG'"$clear"'JJ'"$cyan"'PGBBBBBBBG5'"$clear"'#'
    echo '   B'"$cyan"'YGGGGGG'"$clear"'JBGP'"$cyan"'5PGGBG5G'"$clear"'&'
    echo '   G'"$cyan"'YGGGGGG'"$clear"'JB'"$blue"'##'"$clear"'BBG'"$cyan"'PY5'"$clear"'#'
    echo '   G'"$cyan"'YGGGGGP'"$clear"'?G'"$blue"'######'"$clear"'BGPP'
    echo '   G'"$cyan"'YGGP'"$clear"'55PGGPPG'"$blue"'B######'"$clear"'5G'
    echo '   P'"$cyan"'YP'"$clear"'5P'"$blue"'B#&&&#'"$clear"'BGPPG'"$blue"'B###'"$clear"'PG'
    echo '   BJP'"$blue"'B&&&&&#&&&&#'"$clear"'BGPP'"$blue"'B'"$clear"'5G'
    echo '     &BGGG'"$blue"'B#&&&&#&&&#'"$clear"'B5J#'
    echo '         #BGG'"$blue"'BB#&#'"$clear"'BGGB#'
    echo '           &#BGPGB&'
end

function _sauce_print_header
    set -l date (date +'%A, %b %d, %Y')
    set -l host
    if command -q figlet
        set host (figlet -f smslant "@"(hostname) 2>/dev/null | sed 's/^/ /' | string collect)
    end
    test -n "$host"; or set host ' @'(hostname)
    clear
    echo "$yellow$line$clear"
    echo "$nameColor$host$clear"
    echo ''
    echo "  $dateColor$date$clear"
    echo "  $nameColor"(whoami)'@'(hostname)"$clear"
    echo ''
    for il in (get_ips)
        echo "  $nameColor$il$clear"
    end
    echo ''
    echo "$yellow$line$clear"
    echo ''
    pretty_lights
    echo ''
    echo ''
    echo "$magenta$oil$pad"'across the universe divide...'"$clear"
    echo ''
    echo "$yellow$line$clear"
    echo ''
end

function list_docker_containers
    if not command -q docker
        echo "docker is not installed."
        return 1
    end
    if not docker info >/dev/null 2>&1
        echo "The Docker daemon is not running."
        return 1
    end
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
        for ps_result in (docker ps -a --format "{{.Status}} | {{.Names}} | {{.Image}} | {{.Ports}}" 2>/dev/null | grep "$container_status ")
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

function update
    if test (uname) = Darwin
        brew update; and brew upgrade; and brew upgrade --cask
        return
    end
    if command -q apt
        sudo apt update; and sudo apt upgrade -y; and sudo apt dist-upgrade -y
    else if command -q pacman
        sudo pacman -Syu; and paru -Syu
    else if command -q dnf
        sudo dnf upgrade -y
    end
    command -q flatpak; and flatpak update --user -y
end

alias docker-containers 'list_docker_containers'
alias sauce 'chezmoi apply'
alias sauce-edit 'chezmoi edit --apply'
alias sauce-cd 'chezmoi cd'

if test -d $SAUCE_DIR/scripts
    for _script in $SAUCE_DIR/scripts/*.sh
        test -e $_script; or continue
        test (basename $_script) = functions.sh; and continue
        alias (basename $_script .sh) "bash $_script"
    end
    set -e _script
end
# configure fish -------------------------------------------------------------------
if command -q dotnet
    complete -f -c dotnet -a '(dotnet complete (commandline -cp))'
end
# visual components -----------------------------------------------------------------
if status is-interactive
    _sauce_print_header
    if type -q oh-my-posh; and test -f "$THEME_DIR/sauce.toml"
        oh-my-posh init fish --config "$THEME_DIR/sauce.toml" | source
    end
end
# post load -------------------------------------------------------------------------
for _rc in $RCs
    test -r $_rc; and source $_rc
end
set -e _rc
