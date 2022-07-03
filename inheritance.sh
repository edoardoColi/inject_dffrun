#!/bin/bash

num_args=$#
working_dir=$(pwd)
if [ $num_args != 1 ] && [ $num_args != 4 ] && [ $num_args -lt 5 ]; then
	echo "usage: ./$(basename "$0") [user@]hostname [path_dffrun path_executable path_JSONconfig [file_needed...]]"
	exit 1
fi

check_dir()
{
cd "$2"
if [ ! -d $(dirname "$1") ]; then
	echo "$(dirname "$1") is not an existing directory"
	exit 1;
fi
}

check_file()
{
if [ ! -f "$1" ]; then
	echo "$(basename "$1") is not a valid file"
	exit 1;
fi
}

#TODO controlla il parametro $1

if [ ! -d ~/opt/fastflow/.ssh ]; then
	mkdir -p ~/opt/fastflow/.ssh
	chmod 700 ~/opt/fastflow/.ssh
fi
cd ~/opt/fastflow/.ssh
if ! [ -f ff_key ] || ! [ -f ff_key.pub ]; then
	rm -f ff_key ff_key.pub
	ssh-keygen -f ff_key -t rsa -N "" &>/dev/null
fi

ssh-copy-id -i ~/opt/fastflow/.ssh/ff_key.pub "$1" &>/dev/null
if [ $? = 1 ]; then
	exit 1;
fi
if [ $num_args = 1 ]; then
	exit 0;
fi

check_dir $2 $working_dir
check_dir $3 $working_dir
check_dir $4 $working_dir
if [ $num_args -ge 5 ]; then
	check_dir $5 $working_dir #TODO forse non serve il 5 perche e' come il 6
	#TODO le dir degli altri files
fi

cd $(dirname "$2")
path_dffrun=$(pwd)/$(basename "$2")
cd "$working_dir"
cd $(dirname "$3")
path_exec=$(pwd)/$(basename "$3")
cd "$working_dir"
cd $(dirname "$4")
path_JSON=$(pwd)/$(basename "$4")

check_file $path_dffrun
check_file $path_exec
check_file $path_JSON
#TODO controllo che i files esistano (5,6,7,8...) ORA POTEVO controllare solo questo senza la directory?

#OTTIMIZZAZIONE se e' la prima volta scp senno' rsynk (dovrebbe essere piu veloce scp se non ho nulla di gia inserito)
#faccio un oggetto per volta o tutto insieme una volta copiato tutto in un posto?
quit=0
ldd "$path_dffrun" &>/dev/null
if [ $? != 0 ]; then
	echo "Problem about $2"
	quit=1
fi
ldd "$path_exec" &>/dev/null
if [ $? != 0 ]; then
	echo "Problem about $3"
	quit=1
fi
if [ $quit != 0 ]; then
	echo
	echo "usage: ./$(basename "$0") [user@]hostname [path_dffrun path_executable path_JSONconfig [file_needed...]]"
	exit 1
fi

ssh -i ~/opt/fastflow/.ssh/ff_key "$1" "mkdir -p ~/opt/fastflow/lib"
ldd /bin/bash | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
ldd "$path_dffrun" | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
ldd "$path_exec" | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_dffrun "$1":~/opt/fastflow/
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_exec "$1":~/opt/fastflow/
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_JSON "$1":~/opt/fastflow/
#TODO passare anche gli altri file necessari
