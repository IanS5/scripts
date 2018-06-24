#!/usr/bin/fish

function __ians5_proj_has_project
    set -l args (commandline -o)
    if test -z (echo "$args" | grep -- '\-.*P'); and test -z (echo "$args" | grep -- '\-\-project')
        return 1
    end
end

function __ians5_proj_has_project_name
    if test -z (commandline -o | tail -n1 | grep -o -- '\-')
        return 0
    end
    return 1
end

function __ians5_proj_has_template
    set -l args (commandline -o)
    if test -z (echo "$args" | grep -- '\-.*T'); and test -z (echo "$args" | grep -- '\-\-template')
        return 1
    end
end

function __ians5_proj_cursor_on_template
    if not __ians5_proj_has_project; or not __ians5_proj_has_project_name
        return 1
    end
end

complete -c proj -x -n "not __ians5_proj_has_project; and not __ians5_proj_has_template" -a "-P -T"
complete -c proj -f -n "__ians5_proj_has_project; and not __ians5_proj_cursor_on_template" -a "(./proj.sh -lP)"
complete -c proj -f -n "__ians5_proj_has_template; or __ians5_proj_cursor_on_template" -a "(./proj.sh -lT)"

complete -c proj -s l -l list
complete -c proj -s v -l visit
complete -c proj -s c -l create
complete -c proj -s r -l remove
complete -c proj -s b -l backup
complete -c proj -s e -l recover

complete -c proj -s P -l project
complete -c proj -s T -l template
