/* Author: 
 *   Nicolo' Tonci
 *   Edoardo Coli  --WorkInProgress--
 */

#include <iostream>
#include <fstream>
#include <chrono>
#include <thread>
#include <unistd.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <fcntl.h>

#include <cereal/cereal.hpp>
#include <cereal/archives/json.hpp>
#include <cereal/types/string.hpp>
#include <cereal/types/vector.hpp>

#include <filesystem>
namespace n_fs = std::filesystem;

enum Proto {TCP = 1 , MPI};

static inline unsigned long getusec(){			//TODO ??inline
    struct timeval tv;
    gettimeofday(&tv,NULL);
    return (unsigned long)(tv.tv_sec*1e6+tv.tv_usec);
}

//Variabili Globali
Proto						usedProtocol;
bool						seeAll = false;
std::vector<std::string>	viewGroups;
char						hostname[100];
std::string					configFile("");			//TODO assegnazione?
std::string					executable;

bool toBePrinted(std::string gName){
    return (seeAll || (find(viewGroups.begin(), viewGroups.end(), gName) != viewGroups.end()));
}

std::vector<std::string> split (const std::string &s, char delim) {
    std::vector<std::string> result;
    std::stringstream ss(s);
    std::string item;

    while (getline (ss, item, delim))
        result.push_back (item);
    return result;
}

struct G {
    std::string name, host, preCmd;
    int fd = 0;
    FILE* file = nullptr;

    template <class Archive>			//TODO??
    void load( Archive & ar ){
        ar(cereal::make_nvp("name", name));
        
        try {
            std::string endpoint;
            ar(cereal::make_nvp("endpoint", endpoint)); std::vector endp(split(endpoint, ':'));
            host = endp[0]; //port = std::stoi(endp[1]);
        } catch (cereal::Exception&) {
            host = "127.0.0.1"; // set the host to localhost if not found in config file!
            ar.setNextName(nullptr);
        }

        try {
            ar(cereal::make_nvp("preCmd", preCmd)); 
        } catch (cereal::Exception&) {
            ar.setNextName(nullptr);
        }
    }

    void run(){
        char b[1024]; // ssh -t // trovare MAX ARGV
        
        sprintf(b, " %s %s %s %s %s --DFF_Config=%s --DFF_GName=%s %s 2>&1 %s", (isRemote() ? "ssh -T " : ""), (isRemote() ? host.c_str() : ""), (isRemote() ? "'" : ""), this->preCmd.c_str(),  executable.c_str(), configFile.c_str(), this->name.c_str(), toBePrinted(this->name) ? "" : "> /dev/null", (isRemote() ? "'" : ""));
       std::cout << "Executing the following command: " << b << std::endl;
        file = popen(b, "r");
        fd = fileno(file);
        
        if (fd == -1) {
            printf("Failed to run command\n" );
            exit(1);
        }

        int flags = fcntl(fd, F_GETFL, 0); 
        flags |= O_NONBLOCK; 
        fcntl(fd, F_SETFL, flags);
    }

    bool isRemote(){
		return !(!host.compare("127.0.0.1") || !host.compare("localhost") || !host.compare(hostname));
	}


};

bool allTerminated(std::vector<G>& groups){		//TODO la & come una star (*)?
    for (G& g: groups)							//TODO come fosse for(G g;G = ilPrimo; groups successivo) -- per ogni g interno a groups
        if (g.file != nullptr)
            return false;
    return true;
}

static inline void usage(char* progname) {		//TODO ??inline
	std::cout << "\nUSAGE: " <<  progname << " [Options] -f <configFile> <cmd> \n"
			  << "Options: \n"
			  << "\t -v <g1>,...,<g2> \t Prints the output of the specified groups\n"
			  << "\t -V               \t Print the output of all groups\n"
			  << "\t -p \"TCP|MPI\"   \t Force communication protocol\n";
		
}

std::string generateHostFile(std::vector<G>& parsedGroups){
    std::string name = "/tmp/dffHostfile" + std::to_string(getpid());
    std::ofstream tmpFile(name, std::ofstream::out);
  
    for (const G& group : parsedGroups)
        tmpFile << group.host << std::endl;
    tmpFile.close();
    // return the name of the temporary file just created; remember to remove it after the usage
    return name;
}

int main(int argc, char** argv) {

    if (strcmp(argv[0], "--help") == 0 || strcmp(argv[0], "-help") == 0 || strcmp(argv[0], "-h") == 0){
		usage(argv[0]);			//TODO sopra non dovrebbe essere argv[1]?
        exit(EXIT_SUCCESS);
    }

    // get the hostname
    gethostname(hostname, 100);

	int optind=0;
	for(int i=1;i<argc;++i) {
		if (argv[i][0]=='-') {
			switch(argv[i][1]) {		//TODO perche non qui il -h ??
            case 'p' : {
                if (argv[i+1] == NULL) {
                    std::cerr << "-p require a protocol\n";
                    usage(argv[0]);
					exit(EXIT_FAILURE);
                }
                std::string forcedProtocol = std::string(argv[++i]);
                if (forcedProtocol == "MPI")      usedProtocol = Proto::MPI;
                else if (forcedProtocol == "TCP") usedProtocol = Proto::TCP;
                else {
                    std::cerr << "-p require a valid protocol (TCP or MPI)\n";
					exit(EXIT_FAILURE);
                }
            } break;
			case 'f': {
				if (argv[i+1] == NULL) {
					std::cerr << "-f requires a file name\n";
					usage(argv[0]);
					exit(EXIT_FAILURE);
				}
				configFile = n_fs::absolute(n_fs::path(argv[++i])).string();
			} break;
			case 'V': {
				seeAll=true;
			} break;
			case 'v': {
				if (argv[i+1] == NULL) {
					std::cerr << "-v requires at list one argument\n";
					usage(argv[0]);
					exit(EXIT_FAILURE);
				}
				viewGroups = split(argv[i+1], ',');
				i+=viewGroups.size();
			} break;
			}
		}
        else {
            optind=i;
            break;
        }
	}

	if (configFile == "") {
		std::cerr << "ERROR: Missing config file for the loader\n";
		usage(argv[0]);
		exit(EXIT_FAILURE);
	}

    executable = n_fs::absolute(n_fs::path(argv[optind])).string();

	if (!n_fs::exists(executable)) {
		std::cerr << "ERROR: Unable to find the executable file (we found as executable \'" << argv[optind] << "\')\n";
		exit(EXIT_FAILURE);
	}

    executable += " ";                  //TODO costruisco la stringa
		
    for (int index = optind+1 ; index < argc; index++) {
        executable += std::string(argv[index]) + " ";       //TODO perche spazio alla fine?
	}
	
    std::ifstream is(configFile);

    if (!is){
        std::cerr << "Unable to open configuration file for the program!" << std::endl;
        return -1;
    }

    std::vector<G> parsedGroups;

    try {
        cereal::JSONInputArchive ar(is);

        // get the protocol to be used from the configuration file if it was not forced by the command line
        if (!usedProtocol)
            try {
                std::string tmpProtocol;
                ar(cereal::make_nvp("protocol", tmpProtocol));
                if (tmpProtocol == "MPI")
                    usedProtocol = Proto::MPI;
                else 
                    usedProtocol = Proto::TCP;
            }
			catch (cereal::Exception&) {
                ar.setNextName(nullptr);
                // if the protocol is not specified we assume TCP
                usedProtocol = Proto::TCP;
            }

        // parse all the groups in the configuration file
        ar(cereal::make_nvp("groups", parsedGroups));           //TODO cosa sto costruendo? sto usando cereal
    }
	catch (const cereal::Exception& e){
        std::cerr << "Error parsing the JSON config file. Check syntax and structure of  the file and retry!" << std::endl;
        exit(EXIT_FAILURE);
    }

    #ifdef DEBUG
        for(auto& g : parsedGroups)
            std::cout << "Group: " << g.name << " on host " << g.host << std::endl;
    #endif

    if (usedProtocol == Proto::TCP){				//TODO settato tutto incomicio a mandare??
        auto Tstart = getusec();
        for (G& g : parsedGroups)
            g.run();
        
        while(!allTerminated(parsedGroups)){
            for(G& g : parsedGroups){
                if (g.file != nullptr){
                    char buff[1024] = { 0 };
                    
                    ssize_t result = read(g.fd, buff, sizeof(buff));
                    if (result == -1){
                        if (errno == EAGAIN)
                            continue;

                        int code = pclose(g.file);
                        if (WEXITSTATUS(code) != 0)
                            std::cout << "[" << g.name << "][ERR] Report an return code: " << WEXITSTATUS(code) << std::endl;
                        g.file = nullptr;
                    } else if (result > 0){
                        std::cout << buff;
                    } else {
                        int code = pclose(g.file);
                        if (WEXITSTATUS(code) != 0)
                            std::cout << "[" << g.name << "][ERR] Report an return code: " << WEXITSTATUS(code) << std::endl;
                        g.file = nullptr;
                    }
                }
            }

        std::this_thread::sleep_for(std::chrono::milliseconds(15));         //TODO necessario aspettare?
        }
        std::cout << "Elapsed time: " << (getusec()-(Tstart))/1000 << " ms" << std::endl;
    }

    if (usedProtocol == Proto::MPI){                    //TODO come uso MPI
        std::string hostFile = generateHostFile(parsedGroups);
        std::cout << "Hostfile: " << hostFile << std::endl;
        // invoke mpirun using the just created hostfile

        char command[350];
     
        sprintf(command, "mpirun -np %lu --hostfile %s %s --DFF_Config=%s", parsedGroups.size(), hostFile.c_str(), executable.c_str(), configFile.c_str());

        FILE *fp;
        char buff[1024];
        fp = popen(command, "r");
        if (fp == NULL) {
            printf("Failed to run command\n" );
            exit(1);
        }

        /* Read the output a line at a time - output it. */
        while (fgets(buff, sizeof(buff), fp) != NULL) {
            std::cout << buff;
        }

        pclose(fp);

        std::remove(hostFile.c_str());
    }
    
    
    return 0;
}