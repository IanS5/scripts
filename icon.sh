#!/usr/bin/bash

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

icon::find_similar() {
    grep  "$1" $(icon::map::cache) | sed 's/[[:space:]].*//g'
}

flag_escaped=
flag_search=
flag_newline=
flag_names=
declare -a arg_icons
declare -a icons_escaped

for arg in "$@"; do
    case "$arg" in
        "--escaped" |   "-e") flag_escaped=1;;
        "--search"  |   "-s") flag_search=1;;
        "--newline" |   "-n") flag_newline=1;;
        "--names"   |   "-a") flag_names=1;;
        *)
            arg_icons+=( "$arg" )
            ;;
    esac
done

if [[ -n $flag_search ]]; then
    icons_escaped=("$(icon::fzf-search)")
elif [[ -n $flag_names ]]; then
    for icon in "${arg_icons[@]}"; do
        icons_escaped+=("$(icon::find_similar $icon)")
    done
else
    for icon in "${arg_icons[@]}"; do
        icons_escaped+=("$(icon::find $icon)")
    done
fi

for icon in "${icons_escaped[@]}"; do
    if [[ -n $flag_escaped ]] || [[ -n $flag_names ]]; then printf "%s" "$icon"; else printf "$icon"; fi
    if [[ -n $flag_newline ]]; then echo; fi
done