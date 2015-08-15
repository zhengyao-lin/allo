#! /bin/bash

orig_path=$(cd `dirname $0`; pwd)

source $orig_path/general.conf
source $orig_path/message.sh

declare -a TRACE_DEP
RETURN=

is_optional() { # arg1: dep
	local IFS_bak=$IFS
	local is_opt=0

	IFS=" "
	for exp in $1; do
		if [ $exp = "OPT" ]; then
			is_opt=1
		fi
	done
	IFS=$IFS_bak

	RETURN=$is_opt
	return
}

compare_version() { # arg1: src arg2: dest
	local IFS_bak=$IFS
	IFS="." read -a src <<< $1
	IFS="." read -a dest <<< $2

	IFS="."
	i=0
	for v in ${src[@]}; do
		if [ -z ${dest[$i]} ]; then
			RETURN="GT"
			IFS=$IFS_bak
			return
		elif [ $v -gt ${dest[$i]} ]; then
			RETURN="GT"
			IFS=$IFS_bak
			return
		elif [ $v -lt ${dest[$i]} ]; then
			RETURN="LT"
			IFS=$IFS_bak
			return
		fi
		i=`expr $i + 1`
	done
	if [ ${#dest[@]} -gt ${#src[@]} ]; then
		RETURN="LT"
		IFS=$IFS_bak
		return
	fi

	RETURN="EQ"
	IFS=$IFS_bak
	return
} # return: "GT" for greater than; "LT" for less than; "EQ" for equal

find_package() { # arg1: name of the package
	local all_package=`ls $LOGS | grep -P "^$1-[0-9]+(\.([0-9]+))+-[a-z0-9]+$"` #`find $LOGS/$1-*`
	RETURN=$all_package
}

check_version() { # arg1: version arg2+: version condition
# change IFS to normal before calling
	local IFS_bak=$IFS
	local version_found=$1
	local version_cond=$2
	local state="EQ"
	local is_compared=1
	local is_opt=0

	IFS=" "
	for exp in ${version_cond[@]}; do
		case $exp in
			GT|LT|GE|LE|EQ|NOT )
				state=$exp
				;;
			OR )
				state=$exp
				is_compared=1
				;;
			OPT )
				is_opt=1
				;;
			* )
				local version=$exp
				compare_version $version_found $version

				if [ $RETURN == $state ]; then
					is_compared=`expr $is_compared "&" 1`
				elif [ $state = "GE" ] && ([ $RETURN = "GT" ] || [ $RETURN = "EQ" ]); then
					is_compared=`expr $is_compared "&" 1`
				elif [ $state = "LE" ] && ([ $RETURN = "LT" ] || [ $RETURN = "EQ" ]); then
					is_compared=`expr $is_compared "&" 1`
				elif [ $state = "NOT" ] && [ ! $RETURN = "EQ" ]; then
					is_compared=`expr $is_compared "&" 1`
				elif [ $state = "OR" ] && [ $RETURN = "EQ" ]; then
					is_compared=`expr $is_compared "&" 1`
				else
					is_compared=`expr $is_compared "&" 0`
				fi

				state="EQ"
				;;							
		esac
	done
	IFS=$IFS_bak

	if [ $state = "OR" ]; then
		message "Dependency syntax error: expression ended with OR operator" ERROR
		exit_with_error
	fi

	if [ $is_opt = 1 ] && [ $is_compared = 0 ]; then
		RETURN=2
	else
		RETURN=$is_compared
	fi
	return
}

check_deps() { # arg1: dependencies array
	local IFS_bak=$IFS
	local arg=$*
	local need_packages
	IFS="|"
	for dep in ${arg[@]}; do

		local package_name=${dep%%-*}
		local version_dep=${dep##*-}
		version_dep=${version_dep#(}
		version_dep=${version_dep%)}

		# five expressions: GT LT GE LE EQ NOT OR OPT
		# no expressions means EQ
		# echo $version_dep
		find_package $package_name

		IFS=$IFS_bak
		found_package_flag=0

		for package_found in $RETURN; do
			local version_found=$package_found
			version_found=${version_found##*/}
			version_found=${version_found#*-}
			version_found=${version_found%-*}

			check_version $version_found "$version_dep"
			local is_compared=$RETURN

			if [ $is_compared = 1 ]; then
				found_package_flag=1
				break
			fi
		done
		IFS="|"

		if [ $found_package_flag = 0 ]; then
			message "Cannot find package \"$package_name\" comparing version $version_dep installed" WARNING
			need_packages="$need_packages|$dep"
		else
			message "Found dependency $package_name-$version_found installed" NOTE
		fi
	done

	IFS=$IFS_bak
	need_packages=${need_packages#*|}
	RETURN=$need_packages
}

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

trace() { # arg1: package path arg2(optional): false for closing output
	if [ ! -z $2 ]; then
		MSG_FLAG_bak=$MSG_FLAG
		MSG_FLAG=$2
	fi

	#echo $1
	#read a
	local md5=`md5sum $1`

	local boot_path=$(pwd) # $(cd `dirname $0`; pwd)
	local temp_dir="$1.d"
	local pack_dir="$temp_dir/"

	if [ -d $temp_dir ]; then
		rm -r $temp_dir
	fi

	mkdir $temp_dir
	tar -xf $1 --directory=$temp_dir

	cd $pack_dir

	source .packlist

	cd $boot_path
	check_deps $DEPS
	local deps=$RETURN

	local IFS_bak=$IFS
	IFS="|"
	for dep in ${deps[@]}; do
		if [ -z $dep ]; then
			continue
		fi
		message "Searching dependency: $dep in $deps" NOTE
		local version_need=${dep}
		local has_installed=0

		local packages
		local traced_packages
		
		traced_packages=`echo "${TRACE_DEP[@]}" | xargs -n 1 | grep -P "^($SOURCES/)?(.+/)?${dep%%-*}-[0-9]+((\.([0-9]+))+)?\.tar\.gz$" | xargs`
		# echo [$packages]
		# echo ["echo \"${TRACE_DEP[@]}\" | grep -P \"^$SOURCES/(.+/)?${dep%%-*}-[0-9]+((\.([0-9]+))+)?\.tar\.gz\""]

		if [ ! -z "ls $SOURCES" ]; then
			packages=`find $SOURCES/* | grep -P "^$SOURCES/(.+/)?${dep%%-*}-[0-9]+((\.([0-9]+))+)?\.tar\.gz$" | xargs`
		fi

		IFS_bak2=$IFS
		IFS=" "

		local version_dep=${dep##*-}
		version_dep=${version_dep#(}
		version_dep=${version_dep%)}

		for package in $traced_packages; do
			local version=${package##*/}
			version=${version##*-}
			version=${version%.*}
			version=${version%.*}

			IFS_bak3=$IFS
			IFS=" $'\n'$'\t'"
			check_version "$version" "$version_dep"
			IFS=$IFS_bak3
			local is_compared=$RETURN

			if [ "$is_compared" = 1 ]; then
				packages=""
				message "Denpendency $dep has been traced(package $package), ignore" NOTE
				has_installed=1
				break
			fi
		done

		for package in $packages; do
			local version=${package##*/}
			version=${version##*-}
			version=${version%.*}
			version=${version%.*}

			IFS_bak3=$IFS
			IFS=" $'\n'$'\t'"
			check_version "$version" "$version_dep"
			IFS=$IFS_bak3
			local is_compared=$RETURN

			if [ $is_compared = 1 ]; then
				message "[Found $package]"
				trace $package
				if [ ! $? = 0 ]; then
					clean_up
					exit_with_error $1
				fi
				has_installed=1
				break
			elif [ $is_compared = 2 ]; then
				message "Cannot find package comparing optional dependency $dep, ignore" NOTE
				has_installed=1
				break
			fi
		done
		IFS=$IFS_bak2

		if [ $has_installed = 0 ]; then
			is_optional $version_dep
			if [ $RETURN = 1 ]; then
				message "Cannot find optional dependency $dep, ignore" NOTE
				break
			fi

			message "Can't find package $dep needed in sources" ERROR
			clean_up
			exit_with_error $1
		fi
	done
	IFS=$IFS_bak

	TRACE_DEP[${#TRACE_DEP[@]}]=$1

	clean_up

	if [ ! -z $2 ]; then
		MSG_FLAG=$MSG_FLAG_bak
	fi
}
