#!/usr/bin/fish

complete -c proj -s L -l list
complete -c proj -s V -l visit
complete -c proj -s C -l create
complete -c proj -s R -l remove
complete -c proj -s B -l backup
complete -c proj -s E -l recover
complete -c proj -s p -l project -a "(proj -Lp'.*')"
complete -c proj -s t -l template -a "(proj -Lt'.*')"
