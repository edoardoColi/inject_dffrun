#!/bin/bash
if [ -z ${DEBUG+x} ]; then
DEBUG=1
fi
if [ -z ${INJECT+x} ]; then
INJECT=0
fi
if [ -z ${RESTORE+x} ]; then
RESTORE=0
fi

if [ $# -ne 2 ]; then																		# se il numero di argomenti non e' 2
	echo "usage: ./$(basename "$0") dir-fastflow dir-cereal"							# stampo il comando d'uso (nomescript nomedirectory)
	exit 1
fi
if [ ! -d "$1" ]; then																		# se nomedirectory non e' una directory, stampo un errore
	echo "$1 is not a directory"
	exit 1;
fi
if [ ! -d "$2" ]; then																		# se nomedirectory non e' una directory, stampo un errore
	echo "$2 is not a directory"
	exit 1;
fi

green=$(tput setaf 2)																		# colori per il terminale
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
reset=$(tput sgr0)

check_error()																				# se il camando non viene eseguito correttamente ritorna
{
if [ $1 != 0 ]; then          																# controllo che il comando sia andato a buon fine
	echo "${red}Error${reset} while $2"
	exit 1
fi
}

inject_file="$(pwd)/$(dirname $0)/dff_run.cpp"
tmp=$(pwd)
cd "$1"
dir_ff=$(pwd)
cd "$tmp"
cd "$2"
dir_cereal=$(pwd)
echo "${yellow}You are going to use \"$dir_ff\" folder for FastFlow and \"$dir_cereal\" folder for Cereal, do you want to continue? (y/n-default)${reset}"
read yn
if [ "$yn" != "y" ]; then
	exit 0
fi
sudo apt-get -y install wget git make														# installo i comandi necessari
check_error $? "installing dependencies"
###
cereal=cereal-1.3.2
tar_cereal=v1.3.2.tar.gz
https_cereal=https://github.com/USCiLab/cereal/archive/refs/tags/${tar_cereal}
if [ -w $tar_cereal ]; then																	# se il file esiste ed e' scrivibile
	echo -n " ${yellow}$tar_cereal for Cereal exists, Override? (y/n-default)?${reset}"
	read yn																					# leggo un carattere dallo standard input
	if [ "$yn" = "y" ]; then
		rm -f $tar_cereal;																	# cancelle il vecchio file esistente
		wget ${https_cereal}																# recupero i file online
		check_error $? "downloading $cereal file from $https_cereal"
	fi
else
	echo "${yellow}No references found for Cereal in $dir_cereal directory.${reset}"
	wget ${https_cereal}																	# recupero i file online
	check_error $? "downloading $cereal file from $https_cereal"
	yn=y
fi
if [ -d $cereal ]; then																		# se esiste la cartella
	if [ "$yn" = "y" ]; then																# aggiorno se lo ho scaricato di nuovo
		rm -fr $cereal
		tar -xf $tar_cereal																	# estraggo dal file scaricato
		check_error $? "extracting $cereal files"
	fi
else
	tar -xf $tar_cereal																		# estraggo dal file scaricato
	check_error $? "extracting $cereal files"
fi
###
ff=fastflow
git_ff=https://github.com/fastflow/${ff}.git
cd "$dir_ff"
if [ -d $ff ]; then
	echo -n " ${yellow}$ff for FastFlow from GitHub exists, Override? (y/n-default)${reset}"
	read yn																					# leggo un carattere dallo standard input
	if [ "$yn" = "y" ]; then
		rm -fr $ff;																			# cancelle il vecchio file esistente
		git clone ${git_ff}																	# recupero i file online
		check_error $? "cloning $ff from GitHub repository: $git_ff"
	fi
else
	echo "${yellow}No references found for FastFlow in $dir_ff directory.${reset}"
	git clone ${git_ff}																		# recupero i file online
	check_error $? "cloning $ff from GitHub repository: $git_ff"
fi
cd "$ff"
git checkout DistributedFF
check_error $? "git checkout DistributedFF"
git pull																					# da eseguire periodicamente
check_error $? "git pull"
cd ..
###
#Dettagli su gcc a https://gcc.gnu.org/projects/cxx-status.html
uname -s | grep Linux &>/dev/null															# controlliamo il sistema dove ci troviamo #TODO e se sono su centos? tutti i comandi che uso vanno bene??
if [ $? = 0 ]; then
	ppa=ubuntu-toolchain-r/test
	sudo add-apt-repository -yu ppa:${ppa}
#	check_error $? "adding the ppa:${ppa}(Personal Packet Archive)"
	sudo apt-get -y install gcc-10
	check_error $? "installing gcc-10"
	sudo apt-get -y install g++-10
	check_error $? "installing g++-10"
else
	echo "${yellow}Check for Kernel${reset}"
fi
###
export FF_HOME="$dir_ff/$ff"
export CEREAL_HOME="$dir_cereal/$cereal/include"

echo "${yellow}It might take a while, do you want to use make command for all tests? (y/n-default)"
echo "Alternatively, follow the instructions in .\\Workflow${reset}"
read yn
cd fastflow/ff/distributed/loader
if [ $INJECT = 1 ]; then #TODO aggiungere anche i vari script che usa il dff_run (tipo inheritance.sh)
	echo
	echo "-Injection"
	if [ -f "$inject_file" ]; then
		mv -fv ./dff_run.cpp ./dff_run.cpp.old 
		cp -fv "$inject_file" .
		echo "${green}DONE${reset}"
	else
		echo "${red}NO FILE(dff_run.cpp) TO INJECT${reset}"
	fi
fi
if [ $RESTORE = 1 ]; then
	echo
	echo "-Restore"
	mv -fv ./dff_run.cpp ./dff_run.cpp.old
	git checkout ./dff_run.cpp
	if [ $? != 0 ]; then
		mv -fv ./dff_run.cpp.old ./dff_run.cpp
		echo "${red}CAN'T RESTORE FILE(dff_run.cpp) NOW${reset}"
	else
		echo "${green}DONE${reset}"
	fi
fi
if [ $DEBUG = 1 ]; then
	echo
	make cleanall
	DEBUG=1 CXX=g++-10 make
	make clean
	if [ "$yn" = "y" ]; then
		cd ../../../tests/distributed
		make cleanall
		DEBUG=1 CXX=g++-10 make
		make clean
	fi
else
	make cleanall
	CXX=g++-10 make
	make clean
	if [ "$yn" = "y" ]; then
		cd ../../../tests/distributed
		CXX=g++-10 make
		make clean
	fi
fi

gnome-terminal &>/dev/null																	# le variabili esportate rimangono settate nel processo figlio
echo "${yellow}Remind to set variables like this:"											# reminder per il processo padre
echo "  export FF_HOME=$dir_ff/$ff"
echo "  export CEREAL_HOME=$dir_cereal/$cereal/include${reset}"

exit 0
