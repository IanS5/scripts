#!/bin/bash
TARGET=$2
SOURCE=$1

mkdir -p "$TARGET" "$SOURCE"
while [ 1 ]; do
	IFS=';' read -r -a event_file <<< "`inotifywait -r --format '%e;%f' -e move -e create -e delete $1 $SOURCE`"

	if [ "$?" != '0' ]; then exit 1; fi

	event="${event_file[0]}"
	file="${event_file[1]}"
	printf "\nevent = \"%s\"\nfile = \"%s\"\n\n" "$event" "$file"
	case "$event" in
		CREATE | MOVE_TO)
			mkdir -p "`dirname "$TARGET/$file"`"
			cp -al "$SOURCE/$file" "$TARGET/$file"	
			;;
		DELETE | MOVE_FROM)
			rm  -rf "$TARGET/$file"
			;;
	esac
done
