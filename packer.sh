#! /bin/bash

source message.sh

exit_with_error() { # arg1: package name
	exit 1
}

clean_up() {
	rm -r $tmp_dir
}

MAGIC=
INSTALLER=
DEPS=
INST_FILE_DIR=".inst"

INST_FILE=
OUTPUT=

declare -a FILES

# var_state=
# config_state=
while (( $# > 0 ));do
	arg=$1
	shift
	case $arg in
		--* )
			# var_state=${arg#--}
			var_state=${arg#--}
			val=${var_state%%=*}
			value=${var_state#*=}
			
			eval "$val=\"$value\""
			;;
		-* )
			config_state=${arg#-}
			case $config_state in # TODO add config
				* )
					;;
			esac
			;;
		* )
			FILES[${#FILES[@]}]=$arg
			;;
	esac
done

if [ -z $OUTPUT ]; then
	OUTPUT=$MAGIC
fi

tmp_dir="$OUTPUT.tar.gz.d"
if [ -d $tmp_dir ]; then
	rm -r $tmp_dir
fi
mkdir "$tmp_dir"

message "Generating .packlist..." NOTE
echo -n "#! /bin/bash
MAGIC=\"$MAGIC\"
INSTALLER=\"$INSTALLER\"
DEPS=\"$DEPS\"
INST_FILE_DIR=\"$INST_FILE_DIR\"
" >> "$tmp_dir/.packlist"

mkdir "$tmp_dir/$INST_FILE_DIR"

for file in ${INST_FILE[@]}; do
	if [ ! ${file:0:1} = "/" ]; then
		message "Instant files must be declared with absolute paths!" ERROR
		clean_up
		exit_with_error
	fi

	dir=${file%/*}
	if [ ! -z $dir ]; then
		mkdir -p "$tmp_dir/$INST_FILE_DIR$dir"
	fi

	
	cp -r "$file" "$tmp_dir/$INST_FILE_DIR$dir"
done

for file in ${FILES[@]}; do
	message "Copying file $file..." NOTE
	if [ ! -f $file ] && [ ! -d $file ]; then
		message "Cannot find file $file" ERROR
		clean_up
		exit_with_error
	fi
	cp -r $file "$tmp_dir"
done

message "Creating package..." NOTE
tar -czf $OUTPUT.tar.gz --directory=$tmp_dir `ls -A $tmp_dir`

clean_up
