#!/usr/bin/bash

if [[ -z "$PROJ_BASE_DIR" ]]; then
    PROJ_BASE_DIR="$HOME/.proj"
fi


ESSENTIALS="$PROJ_BASE_DIR/backups $PROJ_BASE_DIR/projects $PROJ_BASE_DIR/templates"
CALL_NAME="$0"

for dir in $ESSENTIALS; do
    if [ ! -d $dir ]; then
        mkdir -p "$dir"
    fi
done

_usage() {
    echo "USAGE:"
    printf "\t$CALL_NAME SUBCOMMAND [ARGS...]\n"
    echo "SUBCOMMANDS:"
    printf "\tbackup [project|template NAME]\n"
    printf "\t\tbackup the project or template 'NAME', if the project/template is not specified then backup everything\n"
    printf "\tproject create|remove NAME [TEMPLATE]\n"
    printf "\t\tcreate or remove a project 'NAME', if the project is being created base it on 'TEMPLATE'\n"
    printf "\ttemplate create|remove NAME\n"
    printf "\t\tcreate or remove a template 'NAME'\n"
}

backup() {
    type="$1"
    subdir="$2"

    pushd "$PROJ_BASE_DIR" > /dev/null

    if [ -z "$type" ]; then
        backup_name="$PROJ_BASE_DIR/backups/`date +'%s'`.bak"
        latest="backups/latest.bak"
        target="."
    elif [ -n "$subdir" ]; then
        backup_name="$PROJ_BASE_DIR/backups/$type.$subdir.`date +'%s'`.bak"
        latest="backups/$type.$subdir.latest.bak"
        target="$type/$subdir"
    else
        echo "please specify a $type name"
        _usage
        exit 1
    fi

    tar --use-compress-program="gzip --best" \
        --exclude-vcs-ignores                \
        --exclude "backups/*"                \
        -cf "$backup_name"                   \
        "$target" &> /dev/null
    
    rm -f "$latest"
    ln -s "$backup_name" "$latest"

    popd > /dev/null
}


project() {
    case "$1" in
        c | cr | cre | crea | creat | create)
            project-create "$2" "$3" ;;
        r | re | rem | remov | remove)
            backup project "$2"
            rm -r "$PROJ_BASE_DIR/projects/$2"
        ;;
        *) ls "$PROJ_BASE_DIR/projects"
    esac
}


template() {
    case "$1" in
        c | cr | cre | crea | creat | create)
            template-create "$2" "$3" ;;
        r | re | rem | remov | remove)
            backup template "$2"
            rm -r "$PROJ_BASE_DIR/templates/$2"
        ;;
        *) ls "$PROJ_BASE_DIR/templates"
    esac
}



project-create() {
    name="$1"
    template="$2"

    if [ -z "$name" ]; then
        echo "please specify a project name"
        _usage
        exit 1
    fi

    if [ -z "$template" ]; then
        template="scratch"
    fi

    if [[ -d $PROJ_BASE_DIR/templates/"$template" ]]; then
        template_dir=$PROJ_BASE_DIR/templates/"$template"
    elif [[ -d /etc/proj/templates/"$template" ]]; then
        template_dir=/etc/proj/templates/"$template"
    else
        echo "no template named 'scratch'"
        echo "do \"$CALL_NAME template create $template\" to create it" 
        exit 1
    fi

    cp -frp $template_dir "$PROJ_BASE_DIR/projects/$name"
    
    pushd "$PROJ_BASE_DIR/projects/$name" > /dev/null
    export TEMPLATE=$template
    export PROJECT=$name
    
    sh ./PROJINIT
    init_rc=$?
    
    unset TEMPLATE
    unset PROJECT

    popd > /dev/null

    if [ "$init_rc" != "0" ]; then
        echo "failed to initialize project, exit code $init_rc"
        exit 1
    fi

    rm "$PROJ_BASE_DIR/projects/$name/PROJINIT"
}

template-create() {
    name="$1"

    if [ -z "$name" ]; then
        echo "please specify a template name"
        _usage
        exit 1
    fi
    mkdir -p "$PROJ_BASE_DIR/templates/$name"
    cat > "$PROJ_BASE_DIR/templates/$name/PROJINIT" << EOF
#!/usr/bin/bash
echo "building project \\"\$PROJECT\\" based on template \\"\$TEMPLATE\\""
EOF
    chmod +x "$PROJ_BASE_DIR/templates/$name/PROJINIT"
}


case "$1" in
    p | pr | pro | proj | proje | projec | project)
        project "$2" "$3" "$4";;
    t | te | tem | temp | templa | templat | template)
        template "$2" "$3";;
    b | ba | bac | back | backu | backup)
        backup "$2" "$3";;
    cd)
        cd "$PROJ_BASE_DIR/projects/$2"
        ;;
    *)
        echo "unkown subcommand"
        _usage
        exit 1
        ;;
esac