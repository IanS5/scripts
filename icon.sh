#!/bin/bash
#
# Usage: icon [-esna] [ICON] ...
#        icon [-h | --help]
#
# Find an icon from the nerd font's (or similar fonts) CSS.
#
# Arguments:
#   ICON  the icon's name
#
# Options:
#   -h, --help
#   -e, --esaped    print the icons unicode codepoint in the form of `\uXXXX' instead of the icon itself
#   -s, --search    use fzf to search the available icons
#   -n, --newlines  seperate the icons with a newline
#   -a, --names     return icons that contain ICON in their name


if [[ -z "$ICON_PREFIX" ]]; then
    export ICON_PREFIX=""
fi

if [[ -z "$ICON_CSS_URL" ]]; then
    export ICON_CSS_URL="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/css/nerd-fonts-generated.css"
fi

if [[ -z "$ICON_CSS_URL_ID" ]]; then
    export ICON_CSS_URL_ID="$(echo "$ICON_CSS_URL::$ICON_PREFIX" | md5sum | cut -f1 -d" ")"
fi

if [[ -z "$ICON_MAP_FILE_EXT" ]]; then
    export ICON_MAP_FILE_EXT="icon.sh.map"
fi

if [[ -z "$ICON_CACHE_DIR" ]]; then
    export ICON_CACHE_DIR="$HOME/.local/share/icon.sh"
fi

[[ -d $ICON_CACHE_DIR ]] || mkdir -p "$ICON_CACHE_DIR"

icon::map::from-css() {
    local url="$1"
    local filename="$2"
    local unicode_delim=" "
    local name_delim=":"

    [ -f "$filename" ] || curl -s "$url" > "$filename"

    awk -f- $filename <<-EOF
        /\.$ICON_PREFIX.*:before/ {
            if (\$0 ~ /,\$/) {
                gsub(/:before.*\,/, "", \$0)
                gsub(/\\.$ICON_PREFIX/, "", \$0)
                
                printf "%s$name_delim", \$0
            } else {
                getline content
                
                gsub(/:before.*{/, "", \$0)
                gsub(/\.$ICON_PREFIX/, "", \$0)

                gsub(/^.*content:[^\\"]*\\"/, "", content)
                gsub(/\\";\$/, "", content)
                gsub(/\\\/, "\\\u", content)
                
                printf "%s$unicode_delim%s\n", \$0, content
            }
        }
EOF
}

icon::map::cache() {
    local mapfile="$ICON_CACHE_DIR/"$ICON_CSS_URL_ID".icon.sh.map"

    if [[ ! -f $mapfile ]]; then
        icon::map::from-css "$ICON_CSS_URL" "/tmp/$ICON_CSS_URL_ID" > "$mapfile"
    fi

    echo "$mapfile"
}

icon::fzf-search() {
    local cache=$(icon::map::cache)
    local icon=$(awk '{split($1, names, ":"); for(name in names) printf "%s\n", names[name];}' $cache | fzf)
    printf "%s" "$(icon::find $icon)"
}

icon::find() {
    grep "^$1[[:space:]]" $(icon::map::cache) | sed 's/.*[[:space:]]//g'
}

icon::find-similar() {
    grep  "$1" $(icon::map::cache) | sed 's/[[:space:]].*//g'
}

source docopts.sh --auto "$@"

declare -a icons_escaped

if [[ ${ARGS[--search]} = 'true' ]]; then
    icons_escaped=("$(icon::fzf-search)")
elif [[ ${ARGS[--names]} = 'true' ]]; then
    for i in `seq 0 $(expr ${ARGS[ICON,#]} - 1)`; do
        icons_escaped+=("$(icon::find-similar ${ARGS[ICON,$i]})")
    done
else
    for i in `seq 0 $(expr ${ARGS[ICON,#]} - 1)`; do
        icons_escaped+=("$(icon::find ${ARGS[ICON,$i]})")
    done
fi

for icon in "${icons_escaped[@]}"; do
    if [[ ${ARGS[--escaped]} = 'true' ]] || [[ ${ARGS[--names]} = 'true' ]]; then printf "%s" "$icon"; else printf "$icon"; fi
    if [[ ${ARGS[--newline]} = 'true' ]]; then echo; fi
done