#!/usr/bin/bash

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

if [[ -z "$PROJ_COMPRESSION_METHOD" ]]; then
    PROJ_COMPRESSION_METHOD="lzma"
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

proj::fail() {
    echo "proj: $1"
    exit 1
}

proj::binary-query() {
    read -p "$1 [Y/n] " response
    [[ "$response" =~ [yY]([eE][sS])? ]]
    return $?
}

proj::completion() {
    if [[ -n "$PROJ_COMPLETIONS" ]] && [[ -z "$1" ]]; then
        echo "$2" | tr ' ' '\n'
        exit
    fi
}

proj::completion::stop() {
    if [[ -n "$PROJ_COMPLETIONS" ]]; then
        if [[ -z "$1" ]] && [[ -n "$2" ]]; then
            echo "$2" | tr ' ' '\n'
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

proj::backup::compress() {
    case "$PROJ_COMPRESSION_METHOD" in
        "lzma")
            XZ_OPTS='-9' \
            tar --exclude-vcs-ignores --lzma --create --file "$@"
            ;;
        "gzip")
            GZIP_OPTS='-9' \
            tar --exclude-vcs-ignores --gzip --create --file "$@"
            ;;
        "bzip2")
            BZ_OPTS='-9' \
            tar --exclude-vcs-ignores  --bzip2 --create --file "$@"
            ;;
        *)
            proj::fail "unknown compression type '$PROJ_COMPRESSION_METHOD'"
            ;;
    esac
}

proj::backup() {
    resource="$1"
    name="$2"

    proj::completion $resource "project template all"
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

    proj::backup::compress "$backup" "./$name"
    
    rm -f "$latest"
    ln -s "$backup" "$latest"

    proj::leave
}

proj::projects::list() {
    find $PROJ_PROJECT_DIR -maxdepth 1 -print -type d | grep -oP "(?<=($PROJ_PROJECT_DIR/)).*"
}

proj::templates::list() {
    find $PROJ_TEMPLATE_DIR -maxdepth 1 -print -type d | grep -oP "(?<=($PROJ_TEMPLATE_DIR/)).*"
    find /etc/proj/templates -maxdepth 1 -print -type d | grep -oP "(?<=(/etc/proj/templates/)).*"
}


proj::projects::create() {    
    name="$1"
    template="$2"
    echo $name
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
    proj::completion "$1" "create remove backup"

    case "$1" in
        c | cr | cre | crea | creat | create)
            proj::projects::create "$2" "$3"
            ;;
        r | re | rem | remov | remove | rm)
            proj::completion "$2" "$(proj::projects::list)"
            proj::binary-query "Are you sure you want to delete '$2'?" || exit
            proj::backup project "$2"
            rm -r "$PROJ_PROJECT_DIR/$2"
            ;;
        b | ba | bac | back | backu | backup | bak)
            proj::backup project "$2"
            ;;
        *)
            proj::projects::list | grep -s "$1"
            ;;
    esac
}


proj::templates() {
    proj::completion "$1" "create remove backup"

    case "$1" in
        c | cr | cre | crea | creat | create)
            proj::templates::create "$2" "$3"
            ;;
        r | re | rem | remov | remove)
            proj::completion "$2" "$(proj::templates::list)"
            proj::binary-query "Are you sure you want to delete '$2'?" || exit
            proj::backup template "$2"
            rm -r "$PROJ_BASE_DIR/templates/$2"
            ;;
        b | ba | bac | back | backu | backup | bak)
            proj::backup template "$2"
            ;;
        *)
            proj::projects::list | grep -s "$1"
            ;;
    esac
}

proj::generate-completion-script() {
    echo "complete -f -c proj -a \"(proj --_completion (commandline -cop))\""
}


proj::completion "$1" "project template mkcompletions cd help"

case "$1" in
    p | pr | pro | proj | proje | projec | project)
        proj::projects "$2" "$3" "$4";;
    t | te | tem | temp | templa | templat | template)
        proj::templates "$2" "$3";;
    --_completion)
        PROJ_COMPLETIONS=1 exec $0 $2 $3 $4 $5 $6 $7 $8 $9
        ;;
    mkcompletions)
        proj::generate-completion-script
        ;;
    cd)
        proj::completion "$2" "$(proj::projects::list)"
        
        cd "$PROJ_BASE_DIR/projects/$2"
        export fish_history="proj_project_`printf $2 | tr -cd '[[:allnum:]]_'`"
        export HISTFILE="$HOME/.proj/.hist/$2"
        clear
        exec $SHELL
        ;;
    "-h" | "--help" | "help" | "")
        proj::usage
        ;;
    *)
        echo "unkown subcommand"
        proj::usage
        proj::fail
        ;;
esac
