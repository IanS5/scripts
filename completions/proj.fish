#!/usr/bin/fish

complete -c proj -x
complete -c proj -x -n 'test -z (commandline -o | sed -n 2p)' -a "cd"
complete -c proj -x -n 'string match -- (commandline -o | sed -n 2p) cd' -a "(proj -lP'.*')"

complete -c proj -x -s l -l list
complete -c proj -x -s c -l create
complete -c proj -x -s r -l remove
complete -c proj -x -s b -l backup
complete -c proj -x -s e -l recover
complete -c proj -x -s P -l project -a "(proj -lP'.*')"
complete -c proj -x -s T -l template -a "(proj -lT'.*')"