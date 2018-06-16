#!/usr/bin/bash

# print the terminal double 
effect::put() {
    echo -n -e "$@"
}

# give a string uniform look
effect::clean-text() {
   echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]-_'
}

effect::fail() {
    effect::set-foreground "red"
    echo "effect: $1"
    effect::reset-foreground
    exit 1
}

effect::set-foreground-16() {
    case $(effect::clean-text "$1") in
        "black"        |  "0") effect::put "\e[30m";;
        "red"          |  "1") effect::put "\e[31m";;
        "green"        |  "2") effect::put "\e[32m";;
        "yellow"       |  "3") effect::put "\e[33m";;
        "blue"         |  "4") effect::put "\e[34m";;
        "magenta"      |  "5") effect::put "\e[35m";;
        "cyan"         |  "6") effect::put "\e[36m";;
        "lightgrey"    |  "7") effect::put "\e[37m";;
        "darkgrey"     |  "8") effect::put "\e[90m";;
        "lightred"     |  "9") effect::put "\e[91m";;
        "lightgreen"   | "10") effect::put "\e[92m";;
        "lightyellow"  | "11") effect::put "\e[93m";;
        "lightblue"    | "12") effect::put "\e[94m";;
        "lightmagenta" | "13") effect::put "\e[95m";;
        "lightcyan"    | "14") effect::put "\e[96m";;
        "white"        | "15") effect::put "\e[97m";;
        *) effect::fail "unkown foreground color \"$1\"";;
    esac
}

effect::set-background-16() {
    case $(effect::clean-text "$1") in
        "black"        |   "0") effect::put "\e[40m";;
        "red"          |  "1") effect::put "\e[41m";;
        "green"        |  "2") effect::put "\e[42m";;
        "yellow"       |  "3") effect::put "\e[43m";;
        "blue"         |  "4") effect::put "\e[44m";;
        "magenta"      |  "5") effect::put "\e[45m";;
        "cyan"         |  "6") effect::put "\e[46m";;
        "lightgrey"    |  "7") effect::put "\e[47m";;
        "darkgrey"     |  "8") effect::put "\e[100m";;
        "lightred"     |  "9") effect::put "\e[101m";;
        "lightgreen"   | "10") effect::put "\e[102m";;
        "lightyellow"  | "11") effect::put "\e[103m";;
        "lightblue"    | "12") effect::put "\e[104m";;
        "lightmagenta" | "13") effect::put "\e[105m";;
        "lightcyan"    | "14") effect::put "\e[106m";;
        "white"        | "15") effect::put "\e[107m";;
        *) effect::fail "unkown background color \"$1\"";;
    esac
}

effect::set-foreground-256() {
    if [[ "$1" -ge 0 ]] && [[ "$1" -le 256 ]]; then
        effect::put "\e[38;5;$1m"
    else
        effect::fail "A 256 color ID must be between 0 and 256, \"$1\" is not."
    fi
}

effect::set-background-256() {
    if [[ "$1" -ge 0 ]] && [[ "$1" -le 256 ]]; then
        effect::put "\e[48;5;$1m"
    else
        effect::fail "A 256 color ID must be between 0 and 256, \"$1\" is not."
    fi
}

effect::reset-background() {
    effect::put "\e[49m"
}

effect::reset-foreground() {
    effect::put "\e[39m"
}


effect::set-bold() {
    effect::put "\e[1m"
}

effect::set-dim() {
    effect::put "\e[2m"
}

effect::set-underline() {
    effect::put "\e[4m"
}

effect::set-blink() {
    effect::put "\e[5m"
}

effect::set-invert() {
    effect::put "\e[7m"
}

effect::set-hide() {
    effect::put "\e[8m"
}

effect::reset-all() {
    effect::put "\e[0m"
}

effect::reset-bold() {
    effect::put "\e[22m"
}

effect::reset-dim() {
    effect::put "\e[22m"
}

effect::reset-underline() {
    effect::put "\e[24m"
}

effect::reset-blink() {
    effect::put "\e[25m"
}

effect::reset-invert() {
    effect::put "\e[27m"
}

effect::reset-hide() {
    effect::put "\e[28m"
}

effect::set-foreground() {
    if [[ "$1" =~ '^[0-9]+$' ]]; then
        if [[ $1 -lt 16 ]]; then
            effect::set-foreground-16 "$1"
        else
            effect::set-foreground-256 "$1"
        fi
    else
        effect::set-foreground-16 "$1"
    fi
}

effect::set-background() {
    if [[ "$1" =~ '^[0-9]+$' ]]; then
        if [[ $1 -lt 16 ]]; then
            effect::set-background-16 "$1"
        else
            effect::set-background-256 "$1"
        fi
    else
        effect::set-background-16 "$1"
    fi
}

effect::command() {
    case "$1" in
        "bold") effect::set-bold;;
        "dim")  effect::set-dim;;
        "underline") effect::set-underline;;
        "blink") effect::set-blink;;
        "invert") effect::set-invert;;
        "hide") effect::set-hide;;
        "!bold") effect::reset-bold;;
        "!dim")  effect::reset-dim;;
        "!underline") effect::reset-underline;;
        "!blink") effect::reset-blink;;
        "!invert") effect::reset-invert;;
        "!hide") effect::reset-hide;;
        "!foreground" | "!f") effect::reset-foreground;;
        "!background" | "!b") effect::reset-background;;
        "foreground="*) effect::set-foreground "$(echo "$1" | sed 's/foreground=//g')";;
        "f="*) effect::set-foreground "$(echo "$1" | sed 's/f=//g')";;
        "background="*) effect::set-background "$(echo "$1" | sed 's/background=//g')";;
        "b="*) effect::set-background "$(echo "$1" | sed 's/b=//g')";;
    esac
}

for arg in "$@"; do
    effect::command "$arg"
done