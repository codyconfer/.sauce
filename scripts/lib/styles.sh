#! /bin/bash

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
linebreak=$'\n'
line="─────────────────────────────────────────────────────"

pretty_lights() {
  local pad
  pad=$(printf '%*s' "${1:-0}" '')
  cat <<_END_ | sed "s/^/${pad}/"
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
_END_
}
