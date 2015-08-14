#! /bin/bash

orig_path=$(cd `dirname $0`; pwd)

source $orig_path/general.conf

if [ ! -d $LOGS ]; then
	mkdir $LOGS
fi
