#! /bin/bash

orig_path=$(cd `dirname $0`; pwd)

source $orig_path/general.conf
source $orig_path/message.sh
source $orig_path/tracer.sh

exit_with_error() { # arg1: package name
	message "Stop the installation of package [$1]"
	exit 1
}

boot_path=$(pwd) # $(cd `dirname $0`; pwd)

if [ ! -f "$1" ]; then
	message "Cannot find package $1" ERROR
	exit_with_error $1
fi

message "Checking dependency..."
trace "$1"

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
