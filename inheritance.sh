#!/bin/bash

num_args=$#
working_dir=$(pwd)
if [ $num_args != 1 ] && [ $num_args != 3 ] && [ $num_args -lt 4 ]; then
	echo "usage: ./$(basename "$0") [user@]hostname [path_executable path_JSONconfig [file_needed...]]"
	exit 1
fi

check_dir()					# Verifica che il path specificato esista
{
cd "$2"
if [ ! -d $(dirname "$1") ]; then
	echo "$(dirname "$1") is not an existing directory"
	exit 1;
fi
}

check_file()					# Verifica che il file sia valido
{
if [ ! -f "$1" ]; then
	echo "$(basename "$1") is not a valid file"
	exit 1;
fi
}

hostname=$1
if ! [[ "${hostname##*@}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then					# Verifica che l'hostname sia del tipo xxx.xxx.xxx.xxx
	echo Invalid hostname: "${hostname##*@}"
	exit 2;
fi

if [ ! -d ~/opt/fastflow/.ssh ]; then					# Crea la cartella per la chiave ssh se non esiste
	mkdir -p ~/opt/fastflow/.ssh
	chmod 700 ~/opt/fastflow/.ssh
fi
cd ~/opt/fastflow/.ssh
if ! [ -f ff_key ] || ! [ -f ff_key.pub ]; then					# Se non ci sono le chiavi le genera
	rm -f ff_key ff_key.pub
	ssh-keygen -f ff_key -t rsa -N "" &>/dev/null
fi

#ssh-copy-id -i ~/opt/fastflow/.ssh/ff_key.pub "$1" &>/dev/null					# Condivide la chiave pubblica per avere un accesso diretto
if [ $? = 1 ]; then
	exit 3;
fi
if [ $num_args = 1 ]; then
	echo Achieve direct network for $1
	exit 0;
fi

check_dir $2 $working_dir			# Controlla le directory di tutti gli elementi passati
check_dir $3 $working_dir
iterator=0
for file in "$@"
do
	iterator=$((iterator+1))
	if [ $iterator -ge 4 ]; then
		check_dir $file $working_dir
	fi
done


cd $(dirname "$2")
path_exec=$(pwd)/$(basename "$2")
cd "$working_dir"
cd $(dirname "$3")
path_JSON=$(pwd)/$(basename "$3")

check_file $path_exec					# Controlla che siano file tutti i files passati
check_file $path_JSON
iterator=0
for file in "$@"
do
	iterator=$((iterator+1))
	if [ $iterator -ge 4 ]; then
		cd "$working_dir"
		cd $(dirname "$file")
		check_file $(pwd)/$(basename "$file") $working_dir
	fi
done

#OTTIMIZZAZIONE se e' la prima volta scp senno' rsynk (dovrebbe essere piu veloce scp se non ho nulla di gia inserito)
#faccio un oggetto per volta o tutto insieme una volta copiato tutto in un posto?
quit=0
ldd "$path_exec" &>/dev/null					# Non e' stato specificato un eseguibile con librerie dinamiche
if [ $? != 0 ]; then
	echo "Problem about $2"
	quit=1
fi
if [ $quit != 0 ]; then
	echo
	echo "usage: ./$(basename "$0") [user@]hostname [path_dffrun path_executable path_JSONconfig [file_needed...]]"
	exit 1
fi

ssh -i ~/opt/fastflow/.ssh/ff_key "$1" "mkdir -p ~/opt/fastflow/lib"					# Controlla le dipendenze degli eseguibili e le sposta nel nodo specificato
ldd /bin/bash | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
ldd "$path_exec" | grep "=> /" | awk '{print $3}' | xargs -I '{}' rsync -rvLE -e "ssh -i ~/opt/fastflow/.ssh/ff_key" '{}' "$1":~/opt/fastflow/lib/
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_exec "$1":~/opt/fastflow/
rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $path_JSON "$1":~/opt/fastflow/
iterator=0
for file in "$@"					# Sposta i files necessari al nodo specificato per l'esecuzione
do
	iterator=$((iterator+1))
	if [ $iterator -ge 4 ]; then
		cd "$working_dir"
		cd $(dirname "$file")
		rsync -vL -e "ssh -i ~/opt/fastflow/.ssh/ff_key" $(pwd)/$(basename "$file") "$1":~/opt/fastflow/
	fi
done

exit 0
