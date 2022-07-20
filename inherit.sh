#!/bin/bash
if [ -z ${CHECK+x} ]; then
CHECK=1																										# Check that the files and their respective paths are correct
fi
if [ -z ${LD+x} ]; then
LD=1																										# Dinamic Libraries are passed
fi
if [ -z ${FILE+x} ]; then
FILE=1																										# "file_needed" are passed
fi


num_args=$#
working_dir=$(pwd)
if [ $num_args != 1 ] && [ $num_args != 3 ] && [ $num_args -lt 4 ]; then
	echo "usage: ./$(basename "$0") [user@]hostname [path_executable path_JSONconfig [file_needed...]]"
	exit 1
fi

check_dir()																									# Verify that the specified path exists
{
cd "$2" &>/dev/null
if [ ! -d $(dirname "$1") ]; then
	echo "$(dirname "$1") is not an existing directory"
	exit 1;
fi
}

check_file()																								# Verify that the file is valid
{
if [ ! -f "$1" ]; then
	echo "$(basename "$1") is not a valid file"
	exit 1;
fi
}

hostname=$1
if [ $CHECK = 1 ]; then
	if ! [[ "${hostname##*@}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then					# Verify that the hostname is of the type xxx.xxx.xxx.xxx
		echo Invalid hostname: "${hostname##*@}"
		exit 2;
	fi
fi

if [ ! -d ~/opt/fastflow/.ssh ]; then																		# Create the folder for the ssh key if it doesn't exist
	mkdir -p ~/opt/fastflow/.ssh
	chmod 700 ~/opt/fastflow/.ssh
fi
cd ~/opt/fastflow/.ssh &>/dev/null
if ! [ -f ff_key ] || ! [ -f ff_key.pub ]; then																# If there are no keys, it generates them
	rm -f ff_key ff_key.pub
	ssh-keygen -f ff_key -t rsa -N "" &>/dev/null
fi

ssh-copy-id -i ~/opt/fastflow/.ssh/ff_key.pub "$1" &>/dev/null												# Share the public key for direct access
if [ $? = 1 ]; then
	exit 3;
fi
if [ $num_args = 1 ]; then
	echo Achieve direct network for $1
	exit 0;
fi

if [ $CHECK = 1 ]; then
	check_dir $2 $working_dir																				# Check the directories of all passed items
	check_dir $3 $working_dir
	iterator=0
	for file in "$@"
	do
		iterator=$((iterator+1))
		if [ $iterator -ge 4 ]; then
			check_dir $file $working_dir
		fi
	done
fi

cd "$working_dir"
cd $(dirname "$2") &>/dev/null
if [ $? = 1 ]; then
	exit 11;
fi
path_exec=$(pwd)/$(basename "$2")
cd "$working_dir"
cd $(dirname "$3") &>/dev/null
if [ $? = 1 ]; then
	exit 11;
fi
path_JSON=$(pwd)/$(basename "$3")

if [ $CHECK = 1 ]; then
	check_file $path_exec																					# Check that all passed files are files
	check_file $path_JSON
	iterator=0
	for file in "$@"
	do
		iterator=$((iterator+1))
		if [ $iterator -ge 4 ]; then
			cd "$working_dir"
			cd $(dirname "$file") &>/dev/null
			if [ $? = 1 ]; then
				exit 11;
			fi
			check_file $(pwd)/$(basename "$file") $working_dir
		fi
	done
fi

ldd "$path_exec" &>/dev/null																				# An executable with dynamic libraries was not specified
if [ $? != 0 ]; then
	echo "Problem about $2"
	echo
	echo "usage: ./$(basename "$0") [user@]hostname [path_executable path_JSONconfig [file_needed...]]"
	exit 1
fi

if [ $LD = 1 ]; then
	ssh -i ~/opt/fastflow/.ssh/ff_key "$1" "mkdir -p ~/opt/fastflow/lib"									# Check the dependencies of the executables and move them to the specified node
	ldd /bin/bash | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
	ldd "$path_exec" | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
fi
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_exec "$1":~/opt/fastflow/
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_JSON "$1":~/opt/fastflow/

if [ $FILE = 1 ]; then
	iterator=0
	for file in "$@"																						# Move necessary files to the specified node for execution
	do
		iterator=$((iterator+1))
		if [ $iterator -ge 4 ]; then
			cd "$working_dir"
			cd $(dirname "$file") &>/dev/null
			rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $(pwd)/$(basename "$file") "$1":~/opt/fastflow/
		fi
	done
fi

exit 0
