NOTE="\e[1;34m"
WARNING="\e[1;33m"
ERROR="\e[1;31m"
NORMAL="\e[0m"
export MSG_FLAG=

message() { # $1: msg, $2: type, $3: if show type
	color=$NORMAL
	prefix=""
	case $2 in
		NOTE|note|N|n )
			prefix="NOTE: "
			color=$NOTE;;
		WARNING|warning|W|w )
			prefix="WARNING: "
			color=$WARNING;;
		ERROR|error|E|e )
			prefix="ERROR: "
			color=$ERROR;;
		* )
			color=$NORMAL;;
	esac
	if [ ! "$3" = "true" ] || [ ! -n "$3" ]; then
		prefix=""
	fi

	if [ ! -z $MSG_FLAG ] && [ $MSG_FLAG = "false" ]; then
		return
	fi

	echo -e "$color$prefix$1$NORMAL"
}
