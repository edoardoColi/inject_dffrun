#!/bin/bash

num_args=$#
if [ $num_args -lt 3 ]; then
	echo "usage: ./$(basename "$0") [user@]hostname path_of_dffrun path_of_executable [files_for_executable]"
	exit 1
fi
working_dir=$(pwd)

#TODO controlla il parametro $1
new_ssh_key=1
if [ ! -d ~/opt/fastflow/.ssh ]; then																		# se non e' una directory stampo un errore
	mkdir -p ~/opt/fastflow/.ssh
	chmod 700 ~/opt/fastflow/.ssh
fi
cd ~/opt/fastflow/.ssh
if [ -f ff_key ] && [ -f ff_key.pub ]; then
	new_ssh_key=0
else
	rm -f ff_key ff_key.pub
	ssh-keygen -f ff_key -t rsa -N ""
fi
#Because we just want to run some command then exit , so no pseudo-terminal is required
#that’s why we can use this option (-T) to disable pseudo-terminal allocation.
#OR call ssh with bash command
if ! ssh -i ~/opt/fastflow/.ssh/ff_key "$1" bash << ENDSSH
	exit
ENDSSH
then
	echo "  Insert password to achieve direct connection"
	ssh-copy-id -i ~/opt/fastflow/.ssh/ff_key.pub "$1" &>/dev/null #TODO fix per indirizzo hostname
fi

cd "$working_dir"
if [ ! -d $(dirname "$2") ]; then																		# se non e' una directory stampo un errore
	echo "$(dirname "$2") is not an existing directory"
	exit 1;
fi
if [ ! -d $(dirname "$3") ]; then																		# se non e' una directory stampo un errore
	echo "$(dirname "$3") is not an existing directory"
	exit 1;
fi

cd $(dirname "$2")
dffrun_path=$(pwd)/$(basename "$2")
cd "$working_dir"
cd $(dirname "$3")
exec_path=$(pwd)/$(basename "$3")

#TODO se e' la prima volta scp senno' rsynk (dovrebbe essere piu veloce scp se non ho nulla di gia inserito)
#faccio un oggetto per volta o tutto insieme una volta copiato tutto in un posto?
quit=0
ldd "$dffrun_path" &>/dev/null
if [ $? != 0 ]; then
	echo "Problem about $2"
	quit=1
fi
ldd "$exec_path" &>/dev/null
if [ $? != 0 ]; then
	echo "Problem about $3"
	quit=1
fi
if [ $quit != 0 ]; then
	echo
	echo "usage: ./$(basename "$0") [user@]hostname path_of_dffrun path_of_executable [files_for_executable]"
	exit 1
fi
ssh -i ~/opt/fastflow/.ssh/ff_key "$1" "mkdir -p ~/opt/fastflow/lib"
ldd /bin/bash | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
ldd "$dffrun_path" | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
ldd "$exec_path" | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/

#TODO passare anche i file necessari all'esecuzione
