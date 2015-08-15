#! /bin/bash

orig_path=$(cd `dirname $0`; pwd)

source $orig_path/general.conf
source $orig_path/message.sh
source $orig_path/tracer.sh

export ROOT_DIR=

declare -a arg_packages

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
			arg_packages[${#arg_packages[@]}]=$arg
			;;
	esac
done

exit_with_error() { # arg1: package name
	message "Stop the installation of package [$1]"
	exit 1
}

boot_path=$(pwd) # $(cd `dirname $0`; pwd)

for pkg in ${arg_packages[@]}; do
	if [ ! -f "$pkg" ]; then
		message "Cannot find package $pkg" ERROR
		exit_with_error $pkg
	fi

	message "Checking dependency..."
	trace "$pkg"
done

message "\nThese package are going to be installed"
message "---------------------"
for package in ${TRACE_DEP[@]}; do
	message $package
done
message "---------------------"
cd $boot_path

message ""
echo -n "Is that OK? (Y/n):"
read ans
case $ans in
	N|n )
		exit
		;;
	* );;
esac

for package in ${TRACE_DEP[@]}; do
	if [ -z $package ]; then
		continue
	fi

	message "Installing [$package]" NOTE
	$orig_path/installer.sh $package
done
