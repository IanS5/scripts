#!/usr/bin/fish

set -l commands "project" "template" "cd"
set -l project_actions "recover" "backup" "create" "find"

complete -f -c proj -x -n "not __ians5_string_in_list (__ians5_get_arg 1) $commands" -a "$commands"
complete -f -c proj -x -n "__ians5_proj_command 'cd'" -a "(proj project)"
complete -f -c proj -x -n "__ians5_proj_command 'project';  and not __ians5_proj_action $project_actions" -a "$project_actions"
complete -f -c proj -x -n "__ians5_proj_command 'project';  and __ians5_proj_action 'find' 'create'"
complete -f -c proj -x -n "__ians5_proj_command 'project';  and __ians5_proj_action 'remove' 'backup'" -a "(proj project fiond)"
complete -f -c proj -x -n "__ians5_proj_command 'project';  and __ians5_proj_action 'create'; and test -n (__ians5_get_arg 3)" -a "(proj template find)"
complete -f -c proj -x -n "__ians5_proj_command 'template'; and __ians5_proj_action 'create'"
complete -f -c proj -x -n "__ians5_proj_command 'template'; and __ians5_proj_action 'remove' 'backup'" -a "(proj template find)"

function __ians5_get_arg
    commandline | string split ' ' | head -n(expr $argv[1] + 1) | tail -n1
end

function __ians5_string_in_list
    if string match -- $argv[1] $argv[2..-1] > /dev/null
        return 0
    else
        return 1
    end
end

alias __ians5_proj_command='__ians5_string_in_list (__ians5_get_arg 1)'
alias __ians5_proj_action='__ians5_string_in_list (__ians5_get_arg 2)'
