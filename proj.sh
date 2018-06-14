#!/usr/bin/bash

PROJ_BACKUP_BLOCKSIZE=10K

if [[ -z "$PROJ_BASE_DIR" ]]; then
    PROJ_BASE_DIR="$HOME/.proj"
fi

if [[ -z "$PROJ_HIST_DIR" ]]; then
    PROJ_HIST_DIR="$PROJ_BASE_DIR/.hist"
fi

if [[ -z "$PROJ_BACKUP_DIR" ]]; then
    PROJ_BACKUP_DIR="$PROJ_BASE_DIR/backups"
fi

if [[ -z "$PROJ_PROJECT_DIR" ]]; then
    PROJ_PROJECT_DIR="$PROJ_BASE_DIR/projects"
fi

if [[ -z "$PROJ_TEMPLATE_DIR" ]]; then
    PROJ_TEMPLATE_DIR="$PROJ_BASE_DIR/templates"
fi

proj::usage() {
    echo "USAGE:"
    printf "\t$0 SUBCOMMAND [ARGS...]\n"
    echo "SUBCOMMANDS:"
    printf "\tproject create | backup | remove NAME [TEMPLATE]\n"
    printf "\t\tcreate, backup or remove a project 'NAME', if the project is being created base it on 'TEMPLATE'\n"
    printf "\ttemplate create | backup | remove NAME\n"
    printf "\t\tcreate, backup or remove a template 'NAME'\n"
    printf "\tcd PROJECT\n"
    printf "\t\tvisit 'PROJECT' in a new shell\n"
}

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
    local frames=('▏' '▎' '▍' '▌' '▋' '▊' '▉' '█')
    local frames_count=${#frames[@]}
    local index=$(echo "trunc($1 * $PROJ_LOADING_LENGTH)" | simplify)
    local partial=$(echo "round(frac($1 * $PROJ_LOADING_LENGTH) * ($frames_count - 1))" | simplify)
    printf "  %3d%%  \u2590" "$(echo "round($1 * 100)" | simplify)"
    if [[ "$index" -gt 1 ]]; then
        printf "${frames[-1]}%.0s" `seq $index`
    fi
    if [[ $index -ne $PROJ_LOADING_LENGTH ]]; then
        if [[ "$index" -gt 0 ]]; then
            printf "${frames[$partial]}"
        fi
    else
        printf "${frames[-1]}"
    fi
    printf "\e[49m"
    if [[ $index -ne $PROJ_LOADING_LENGTH ]]; then
        printf " %.0s" `seq $(expr $PROJ_LOADING_LENGTH - $index)`
    fi
    printf "\e[0m\u258C\r"
}

proj::backup::compress() {
    export precompressed=$(proj::backup::sizeof $1)
    pushd "$1/.." > /dev/null
    proj::load::begin

    XZ_OPTS='-9' tar --exclude-vcs-ignores --checkpoint=1 --xz --create --checkpoint-action=exec='printf "%s\n" "$(simplify "$TAR_CHECKPOINT/$precompressed")"' --file "$2" "./$(basename $1)" |
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
    expr $(xz -l $1 | awk 'NR == 2{printf "%s%.1s\n", $5, $6}' | numfmt --from iec) / $(numfmt --from iec $PROJ_BACKUP_BLOCKSIZE)
}

proj::backup::sizeof() {
    du -hbc -B1$PROJ_BACKUP_BLOCKSIZE --apparent-size $1 | awk '$2 == "total" { print $1 }'
}

proj::fail() {
    echo "proj: $1"
    exit 1
}

proj::binary-query() {
    read -p "$1 [Y/n] " response
    [[ "$response" =~ ([yY]([eE][sS])?) ]]
    return $?
}

proj::completion() {
    if [[ -n "$PROJ_COMPLETIONS" ]] && [[ -z "$1" ]]; then
        echo -e "$2"
        exit
    fi
}

proj::completion::stop() {
    if [[ -n "$PROJ_COMPLETIONS" ]]; then
        if [[ -z "$1" ]] && [[ -n "$2" ]]; then
            echo -e "$2"
        fi
        exit
    fi
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
    resource="$1"
    name="$2"

    proj::completion $resource "project\ntemplate"
    case "$resource" in
        "project")
            proj::completion::stop "$name" "$(proj::backups::list-latest "project")" 
            target="$PROJ_BACKUP_DIR/$name.project.latest.bak"
            directory="$PROJ_PROJECT_DIR/$name"
            ;;
        "template")
            proj::completion::stop "$name" "$(proj::backups::list-latest "template")" 
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

    proj::completion $resource "project\ntemplate\nall"
    case "$resource" in 
        "project")
            proj::completion::stop "$name" "$(proj::projects::list)"
            proj::projects::visit
            ;;
        "template")
            proj::completion::stop "$name" "$(proj::templates::list)"
            proj::templates::visit
            ;;
        "all")
            proj::visit
            ;;
        *)
            proj::fail "Please specify 'project' or 'tempate' or 'all' as a backup target."
            ;;
    esac

    proj::completion::stop

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
    find /etc/proj/templates -maxdepth 1 -print -type d | grep -oP "(?<=(/etc/proj/templates/)).*"
}


proj::projects::create() {    
    name="$1"
    template="$2"

    [[ -z "$name" ]] || proj::completion "$template" "$(proj::templates::list)"
    proj::completion::stop
    
    if [ -z "$template" ]; then
        template="scratch"
    fi

    if [[ -d $PROJ_TEMPLATE_DIR/"$template" ]]; then
        template_dir=$PROJ_TEMPLATE_DIR/"$template"
    elif [[ -d /etc/proj/templates/"$template" ]]; then
        template_dir=/etc/proj/templates/"$template"
    else
        echo "no template named '$template'"
        echo "do \"$0 template create $template\" to create it" 
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
    name="$1"

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

proj::projects() {
    proj::completion "$1" "create\nremove\nrecover\nbackup"

    case "$1" in
        rec | reco | recov | recover)
	    proj::completion::stop "$2" "$(proj::backups::list-latest project)"
	    proj::backup::recover project "$2"
            ;;
	c | cr | cre | crea | creat | create)
            proj::projects::create "$2" "$3"
            ;;
        r | re | rem | remov | remove | rm)
            proj::completion "$2" "$(proj::projects::list)"
            proj::binary-query "Are you sure you want to delete '$2'?" || exit
            proj::backup::backup project "$2"
            rm -r "$PROJ_PROJECT_DIR/$2"
            ;;
        b | ba | bac | back | backu | backup | bak)
            proj::backup::backup project "$2"
            ;;
        *)
            proj::projects::list | grep -s "$1"
            ;;
    esac
}


proj::templates() {
    proj::completion "$1" "create\nremove\nbackup"

    case "$1" in
        c | cr | cre | crea | creat | create)
            proj::templates::create "$2" "$3"
            ;;
        r | re | rem | remov | remove)
            proj::completion "$2" "$(proj::templates::list)"
            proj::binary-query "Are you sure you want to delete '$2'?" || exit
            proj::backup::backup template "$2"
            rm -r "$PROJ_BASE_DIR/templates/$2"
            ;;
        b | ba | bac | back | backu | backup | bak)
            proj::backup::backup template "$2"
            ;;
        *)
            proj::projects::list | grep -s "$1"
            ;;
    esac
}

proj::generate-completion-script() {
    echo "complete -f -c proj -a \"(proj --_completion (commandline -cop))\""
}


proj::completion "$1" "project\ntemplate\ncd\nhelp"

case "$1" in
    p | pr | pro | proj | proje | projec | project)
        proj::projects "$2" "$3" "$4";;
    t | te | tem | temp | templa | templat | template)
        proj::templates "$2" "$3";;
    --_completion)
        PROJ_COMPLETIONS=1 exec $0 $3 $4 $5 $6 $7 $8 $9
        ;;
    mkcompletions)
        proj::generate-completion-script
        ;;
    cd)
        proj::completion "$2" "$(proj::projects::list)"
        
        cd "$PROJ_PROJECT_DIR/$2"
        export PROJ_CURRENT_PROJECT_BASE="$PROJ_PROJECT_DIR/$2"
        export PROJ_CURRENT_PROJECT_NAME="$2"
        export fish_history="proj_project_`printf $2 | tr -cd '[[:allnum:]]_'`"
        export HISTFILE="$HOME/.proj/.hist/$2"
        clear
        exec $SHELL
        ;;
    "-h" | "--help" | "help" | "")
        proj::usage
        ;;
    *)
        proj::completion::stop
        echo "unkown subcommand"
        proj::usage
        proj::fail
        ;;
esac
