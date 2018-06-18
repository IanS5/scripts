complete -c effect -x

complete -c effect -a "foreground=(effect color (commandline -t | sed 's/foreground=//g'))"
complete -c effect -a "background=(effect color (commandline -t | sed 's/background=//g'))"
complete -c effect -a "f=(effect color (commandline -t | sed 's/f=//g'))"
complete -c effect -a "b=(effect color (commandline -t | sed 's/b=//g'))"

complete -c effect -a bold
complete -c effect -a italics
complete -c effect -a underline
complete -c effect -a dim
complete -c effect -a blink
complete -c effect -a invert
complete -c effect -a hide
complete -c effect -a !bold
complete -c effect -a !italics
complete -c effect -a !underline
complete -c effect -a !dim
complete -c effect -a !blink
complete -c effect -a !invert
complete -c effect -a !hide
complete -c effect -a !foreground
complete -c effect -a !background
