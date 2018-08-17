#!/usr/bin/bash
# proj
#
# Usage: proj [options] [<NAME>] [<TEMPLATE>]
#        proj --help
#
# A simple project management script.
#
# Options:
#   -h, --help
#   -T, --template  Operate on a template
#   -P, --project   Operate on a project
#   -l, --list      list all selected resources, <PROJECT> and <TEMPLATE> or considered RegExp(s)
#   -c, --create    create the selected resources
#   -r, --remove    remove the selected resources
#   -b, --backup    make a compressed copy of the selected resources
#   -e, --restore   restore from a compressed copy of the selected resources
#   -v, --visit     visit a project or template's directory in a subshell


PROJ_BACKUP_BLOCKSIZE=10K

# Set default directories.
true ${PROJ_BASE_DIR:="$HOME/.proj"}
true ${PROJ_HIST_DIR:="$PROJ_BASE_DIR/.hist"}
true ${PROJ_BACKUP_DIR:="$PROJ_BASE_DIR/backups"}
true ${PROJ_PROJECT_DIR:="$PROJ_BASE_DIR/projects"}
true ${PROJ_TEMPLATE_DIR:="$PROJ_BASE_DIR/templates"}


proj::load::begin() {
    export PROJ_LOADING_LENGTH=$1
    if [[ -z "$PROJ_LOADING_LENGTH" ]]; then
        PROJ_LOADING_LENGTH=`expr $(tput cols) / 2`;
    fi

    tput civis -- invisible
    echo
    echo
    printf "\033[1A"
}

proj::load::end() {
    proj::load::render_percent 1
    echo
    echo
    tput cnorm -- normal
}

proj::load::render_percent() {
    local percent="$1"
    local frames=('▏' '▎' '▍' '▌' '▋' '▊' '▉' '█')
    local frames_count=${#frames[@]}
    local index=`simplify "trunc($percent * $PROJ_LOADING_LENGTH)"`
    local partial=`simplify "round(frac($percent * $PROJ_LOADING_LENGTH) * ($frames_count - 1))"`

    printf "  %5.2d%%  \u2590" `simplify "$percent * 100"`
    test "$index" -gt 1 && printf "${frames[-1]}%.0s" `seq $index`

    if [[ $index -ne $PROJ_LOADING_LENGTH ]]; then
        if [[ "$index" -gt 0 ]]; then
            printf "${frames[$partial]}"
        fi
    else
        printf "${frames[-1]}"
    fi

    printf "\e[49m"
    test $index -ne $PROJ_LOADING_LENGTH && printf " %.0s" `seq $(expr $PROJ_LOADING_LENGTH - $index)`
    printf "\e[0m\u258C\r"
}

proj::backup::restic() {
    local project="$1"
    restic -r "$PROJ_RESTIC_REPO" \
        backup "$PROJ_PROJECT_DIR/$project"

}

proj::backup::compress() {
    export precompressed=$(proj::backup::sizeof $1)
    pushd "$1/.." > /dev/null
    proj::load::begin

    XZ_OPTS='-9' tar \
        --exclude-vcs-ignores \
        --checkpoint=1 \
        --xz \
        --create \
        --checkpoint-action=exec='printf "%s\n" "$(simplify "$TAR_CHECKPOINT/$precompressed")"' \
        --file "$2" "./$(basename $1)" | \
    while read -r line || [[ -n "$line" ]]; do
        proj::load::render_percent $line
    done

    proj::load::end
    popd > /dev/null
}

proj::backup::decompress() {
    export precompressed=$(proj::backup::sizeof-archive $1)
    if [[ ! -d "$2" ]]; then mkdir "$2"; fi
    proj::load::begin

    XZ_OPTS='-9' tar --checkpoint=1 --xz --extract --checkpoint-action=exec='printf "%s\n" "$(simplify "$TAR_CHECKPOINT/$precompressed")"' --file "$1" -C "$2" |
    while read -r line || [[ -n "$line" ]]; do
        proj::load::render_percent $line
    done
    proj::load::end
}

proj::backup::sizeof-archive() {
    local archive="$1"
    local archive_bytes=$(xz -l $archive | awk 'NR == 2 { printf "%s%.1s\n", $5, $6 }' | tr -d ',' | numfmt --from iec)
    local block_bytes=$(numfmt --from iec $PROJ_BACKUP_BLOCKSIZE)

    printf '%d' $((archive_bytes / block_bytes))
}

proj::backup::sizeof() {
    local folder=$1
    du -hbc -B$PROJ_BACKUP_BLOCKSIZE --apparent-size $archive | awk '$2 == "total" { print $1 }'
}

proj::fail() {
    echo "[proj] $1"
    exit 1
}

proj::binary-query() {
    read -p "$1 [Y/n] " response
    [[ "$response" =~ ([yY]([eE][sS])?) ]]
    return $?
}

proj::projects::visit() {
    pushd "$PROJ_PROJECT_DIR/$1" > /dev/null
}

proj::templates::visit() {
    pushd "$PROJ_TEMPLATE_DIR/$1" > /dev/null
}

proj::visit() {
    pushd "$PROJ_BASE_DIR" > /dev/null
}

proj::leave() {
    popd > /dev/null
}

proj::backup::recover() {
    local resource="$1"
    local name="$2"

    case "$resource" in
        "project")
            target="$PROJ_BACKUP_DIR/$name.project.latest.bak"
            directory="$PROJ_PROJECT_DIR/$name"
            ;;
        "template")
            target="$PROJ_BACKUP_DIR/$name.template.latest.bak"
            directory="$PROJ_TEMPLATE_DIR/$name"
            ;;
        *)
            proj::fail "Please specify 'project' or 'tempate' as a recover target."
            ;;
    esac
    if [[ -d $directory ]]; then
        if [[ -n "`ls -a $directory`" ]]; then
            if proj::binary-query "The $resource $name is not empty, are you sure you want to restore from a backup?"; then
                rm -rf "$directory";
            else
                exit 0
            fi
            mkdir "$directory"
        fi
    else
        mkdir "$directory"
    fi

    proj::backup::decompress "$target" "$directory"
}

proj::backup::backup() {
    resource="$1"
    name="$2"

    case "$resource" in
        "project")
            proj::projects::visit
            ;;
        "template")
            proj::templates::visit
            ;;
        "all")
            proj::visit
            ;;
        *)
            proj::fail "Please specify 'project' or 'tempate' or 'all' as a backup target."
            ;;
    esac

    if [[ ! -d "./$name" ]]; then
        proj::fail "could not find '$name'"
    fi

    latest="$PROJ_BACKUP_DIR/$name.$resource.latest.bak"
    backup="$PROJ_BACKUP_DIR/$name.$resource.`date +%s`.bak"

    proj::backup::compress "./$name" "$backup"

    rm -f "$latest"
    ln -s "$backup" "$latest"

    proj::leave
}

proj::projects::list() {
    find $PROJ_PROJECT_DIR -maxdepth 1 -print -type d | grep -oP "(?<=($PROJ_PROJECT_DIR/)).*"
}

proj::backups::list() {
    find $PROJ_BACKUP_DIR -maxdepth 1 -print -type d  \
        | grep -oP "(?<=($PROJ_BACKUP_DIR/))(.+)(\.$1\.)([0-9]+)(\.bak)" \
        | awk -F'.' -f <(cat - <<-EOF
            \$2 == "$1" {
                printf \$1 " "
                print "date", "-d", "@"\$3, "\"+%m/%d/%Y %H:%M:%S\"" | "/bin/sh"
                close("/bin/sh")
            }
EOF
     ) | sort -r \
       | column -t -s' '
}

proj::backups::list-latest() {
    find $PROJ_BACKUP_DIR -maxdepth 1 -print -type d  \
        | grep -oP "(?<=($PROJ_BACKUP_DIR/))(.+)(\.$1\.latest\.bak)" \
        | awk -F'.' '$3 == "latest" { print $1 }'
}

proj::templates::list() {
    find $PROJ_TEMPLATE_DIR -maxdepth 1 -print -type d | grep -oP "(?<=($PROJ_TEMPLATE_DIR/)).*"

    if [[ -d /etc/proj/templates ]]; then
        find /etc/proj/templates -maxdepth 1 -print -type d | grep -oP "(?<=(/etc/proj/templates/)).*"
    fi
}


proj::projects::create() {
    local name="$1"
    local template="$2"

    if [ -z "$template" ]; then
        template="scratch"
    fi

    if [[ -d $PROJ_TEMPLATE_DIR/"$template" ]]; then
        template_dir=$PROJ_TEMPLATE_DIR/"$template"
    elif [[ -d /etc/proj/templates/"$template" ]]; then
        template_dir=/etc/proj/templates/"$template"
    else
        echo "no template named '$template'"
        echo "do \"$0 --template --create $template\" to create it"
        exit 1
    fi

    if [[ -d $PROJ_PROJECT_DIR/$name ]]; then
        proj::binary-query "The project '$name' already exists, are you sure you want to overwrite it?" || exit
        proj::projects remove "$name"
    fi

    proj::projects::visit

    mkdir -p "$name" && cd "$name"
    cp -frp $template_dir/* "."

    export TEMPLATE=$template
    export PROJECT=$name

    sh ./PROJINIT
    response_code=$?
    rm ./PROJINIT

    proj::leave
    [[ $response_code -eq 0 ]] || proj::fail "failed to initialize project, exit code $response_code"

    unset TEMPLATE
    unset PROJECT
}

proj::templates::create() {
    local name="$1"

    if [ -z "$name" ]; then
        echo "please specify a template name"
        proj::usage
        exit 1
    fi

    mkdir -p "$PROJ_BASE_DIR/templates/$name"
    cat > "$PROJ_BASE_DIR/templates/$name/PROJINIT" << EOF
#!/usr/bin/bash
echo "building project \\"\$PROJECT\\" based on template \\"\$TEMPLATE\\""
EOF
    chmod +x "$PROJ_BASE_DIR/templates/$name/PROJINIT"
}

proj::projects::remove() {
    local project="$1"

    proj::binary-query "Are you sure you want to delete '$project'?" || return

    if [[ "$2" != 'false' ]]; then
        proj::backup::backup 'project' "$project"
    fi

    rm -rf "$PROJ_PROJECT_DIR/$project"
}

proj::templates::remove() {
    local template="$1"

    proj::binary-query "Are you sure you want to delete '$template'?" || return

    if [[ "$2" != 'false' ]]; then
        proj::backup::backup 'template' "$template"
    fi

    rm -rf "$PROJ_TEMPLATE_DIR/$template"
}

proj::projects::cd() {
    local project="$1"

    if [[ ! -d "$PROJ_PROJECT_DIR/$project" ]]; then exit 1; fi

    cd "$PROJ_PROJECT_DIR/$project"

    hash=$(echo "$project" | md5sum | awk '{print $1}')
    export PROJ_CURRENT_PROJECT_BASE="$PROJ_PROJECT_DIR/$project"
    export PROJ_CURRENT_PROJECT_NAME="$project"

    export fish_history="proj_project_$hash"
    export HISTFILE="$HOME/.proj/.hist/project.$hash"

    clear
    exec $SHELL
}

proj::templates::cd() {
    local template="$1"

    if [[ ! -d "$PROJ_PROJECT_DIR/$template" ]]; then exit 1; fi

    cd "$PROJ_PROJECT_DIR/$template"

    hash=$(echo "$template" | md5sum | awk '{print $1}')
    export PROJ_CURRENT_TEMPLATE_BASE="$PROJ_PROJECT_DIR/$template"
    export PROJ_CURRENT_TEMPLATE_NAME="$template"

    export fish_history="proj_project_$hash"
    export HISTFILE="$HOME/.proj/.hist/template.$hash"

    clear
    exec $SHELL
}


arg() {
    local key="$1"
    local val=${ARGS[$key]}
    if [[ "$val" = 'true' ]]; then
        return 0
    elif [[ "$val" = 'false' ]]; then
        return 1
    else
        echo -ne "$val"
    fi
}

source docopts.sh --auto "$@"

if arg --project; then
    project="${ARGS[<NAME>]}"
    template="${ARGS[<TEMPLATE>]}"

    if arg '--list'; then
        proj::projects::list | grep -P -- "$project"
    fi

    if arg '--create'; then
        proj::projects::create "$project" "$template"
    fi

    if arg '--remove'; then
        proj::projects::remove "$project"
    fi

    if arg '--backup'; then
        proj::backup::backup 'project' "$project"
    fi

    if arg '--visit'; then
        proj::projects::cd "$project"
    fi
fi

if arg --template; then
    template="${ARGS[<NAME>]}"

    if arg '--list'; then
        proj::templates::list | grep -P -- "$template"
    fi

    if arg '--create' && [ -z "$project" ]; then
        proj::templates::create "$template"
    fi

    if arg '--remove'; then
        proj::templates::remove "$template"
    fi

    if arg '--backup'; then
        proj::templates::backup 'template' "$template"
    fi

    if arg '--restore'; then
        proj::templates::recover 'template' "$template"
    fi

    if arg '--visit'; then
        proj::templates::cd "$template"
    fi
fi
