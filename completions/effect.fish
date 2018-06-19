complete -c effect -x -a "(__ians5_scripts_complete_effect (commandline -t))"

function __ians5_scripts_complete_effect
    set -l op $argv[1]

    switch "$op"
        case 'foreground=*' 'background=*' 'f=*' 'b=*'
            string replace = ' ' -- $op | read -l key value
            ./effect.sh color $value | awk "{printf \"%s=%s\n\", \"$key\", \$0}"
        case 'f' 'fo*'
            echo "foreground"
        case 'b' 'ba*'
            echo "background"
        case 'bo*'
            echo "bold"
        case 'i' 'it*'
            echo "italics"
        case 'u' 'un*'
            echo "underline"
        case 'd' 'di*'
            echo "dim"
        case 'bl' 'bli*'
            echo "blink"
        case 'in*'
            echo "invert"
        case 'h*'
            echo "hide"
        case '!'
            echo "!bold"
            echo "!italics"
            echo "!underline"
            echo "!dim"
            echo "!blink"
            echo "!invert"
            echo "!foreground"
            echo "!background"
        case '!*'
            __ians5_scripts_complete_effect "(string trim -l -c '!' "$op")"
        case '*'
            echo "bold"
            echo "italics"
            echo "underline"
            echo "dim"
            echo "blink"
            echo "invert"
            echo "!bold"
            echo "!italics"
            echo "!underline"
            echo "!dim"
            echo "!blink"
            echo "!invert"
            echo "!foreground"
            echo "!background"
            echo "foreground="
            echo "background="
    end
end
