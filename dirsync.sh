#!/bin/bash

CALL_NAME="$0"
ARGS=("$@")

_usage() {
    printf "USAGE: $CALL_NAME [-h] [-l] [-r] SOURCE TARGET\n"
    printf "\tsync the contents of TARGET with SOURCE, the connection is one way.\n"
	printf "OPTIONS:\n"
    printf "\t-h: print this message and exit\n"
    printf "\t-l: hard link files instead of copying them\n"
    printf "\t-r: recursively sync all subdirectories of SOURCE\n"

}

FLAG_STOP=`expr "$#" - 2`

if [[ $FLAG_STOP -lt 0 ]]; then
	_usage
	exit 1
fi

LINKS=''
RECURSIVE=''
for i in `seq 0 $FLAG_STOP`; do
	case "${ARGS[$i]}" in
		'-h') 
			_usage
			exit 0
			;;
		'-r') RECURSIVE='1';;
		'-l') LINKS='1';;
	esac
done


if [ -z "$RECURSIVE" ]; then
	WAIT_COMMAND="inotifywait -q --format %,e;%f;%w -e move -e create -e delete"
else
	WAIT_COMMAND="inotifywait -rq --format %,e;%f;%w -e move -e create -e delete"
fi

if [ -z "$LINKS" ]; then
	CP_COMMAND='cp -p'
	WAIT_COMMAND="$WAIT_COMMAND -e close_write -e attrib -e modify"
else
	CP_COMMAND='ln '
fi


SOURCE=${ARGS[$FLAG_STOP]}
TARGET=${ARGS[$(expr 1 + $FLAG_STOP)]}

while true; do
	wait_response=`$WAIT_COMMAND $SOURCE`
	if [[ $? -ne 0 ]]; then exit $?; fi

	IFS=';'  read -r -a event_file <<< "$wait_response"
	IFS=', ' read -r -a events <<< "${event_file[0]}"
	file="${event_file[1]}"
	path="${event_file[2]}"
	echo "$event"
	for event in $events; do
		case "$event" in
			"CREATE" | "MOVE_TO" | "MODIFY" | "CLOSE_WRITE" | "ATTRIB" | "MOVE_FROM")
				if [[ -d $path/$file ]]; then 
					mkdir -p "${path//$SOURCE/$TARGET}/$file";
				else
					`$CP_COMMAND "$path/$file" "${path//$SOURCE/$TARGET}/$file"`
				fi
				;;
			"DELETE")
				rm  -rf "$TARGET/$file"
				;;
		esac
	done
done
