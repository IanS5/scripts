#!/usr/bin/fish

complete -c proj -s l -l list
complete -c proj -s c -l create
complete -c proj -s r -l remove
complete -c proj -s b -l backup
complete -c proj -s e -l recover
complete -c proj -s P -l project -a 'proj -lP""'
complete -c proj -s T -l template -a 'proj -lT""'