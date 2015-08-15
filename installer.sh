#! /bin/bash

orig_path=$(cd `dirname $0`; pwd)

source $orig_path/general.conf
source $orig_path/message.sh

clean_up() {
	if [ ${temp_dir:0:1} = "/" ]; then
		rm -r $temp_dir
	else
		rm -r $boot_path/$temp_dir
	fi
}

exit_with_error() { # arg1: package name
	message "Stop the installation of package [$1]"
	exit 1
}

if [ ! -f "$1" ]; then
	message "Cannot find package $1" ERROR
	exit_with_error $1
fi
md5=`md5sum $1`

boot_path=$(pwd) # $(cd `dirname $0`; pwd)
temp_dir="$1.d"
pack_dir="$temp_dir/"

if [ -d $temp_dir ]; then
	rm -r $temp_dir
fi

mkdir $temp_dir
tar -xf $1 --directory=$temp_dir

cd $pack_dir

source .packlist
if [ -f "$LOGS/$MAGIC-${md5%% *}" ]; then
	message "Package $1 has been installed" NOTE
	clean_up
	exit 0
elif [ ! -z "`ls $LOGS | grep "$MAGIC-*"`" ]; then
	message "Same package($1) of same version has been installed, but with different content. Would you continue installing? (Y/n):"
	read ans
	case $ans in
		N|n )
			clean_up
			exit 0;;
		* );;
	esac
fi

if [ -f $PRE_INSTALLER ]; then
	bash $PRE_INSTALLER
fi

if [ ! -z "$INST_FILE_DIR" ] && [ -d "$INST_FILE_DIR" ] && [ ! -z "`ls -A $INST_FILE_DIR`" ]; then
	find_inst_file="`find "$INST_FILE_DIR" -maxdepth 1`"
	first_flag=1

	message "Instant files:" NOTE
	message "`tree "$INST_FILE_DIR"`"

	message "Install instant files..." NOTE

	for inst_file in $find_inst_file; do
		if [ $first_flag = 1 ]; then
			first_flag=0
			continue
		fi

		target=$inst_file
		if [ ${inst_file:0:1} = "." ]; then
			target=${target:1} # get rid of the beginning dot
		fi
		target="/${target#*/}"

		if [ ! -z $ROOT_DIR ]; then
			message "Redirected root directory $ROOT_DIR" WARNING
		fi

		dir="$ROOT_DIR/${target%/*}"
		if [ ! -z "$dir" ] && [ ! -d "$dir" ]; then
			mkdir -p "$dir"
		fi

		cp -r "$inst_file" "$dir"
	done
fi

bash $INSTALLER
cd $boot_path

# make record
touch "$LOGS/$MAGIC-${md5%% *}"

clean_up
