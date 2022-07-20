/* Author: 
 *   Nicolo' Tonci
 *   Edoardo Coli
 */

void run(){
        char b[1024]; // ssh -t // trovare MAX ARGV
        std::string name_exec;
        std::string name_config;

        name_exec = executable.substr(executable.find_last_of("/\\") + 1);
        name_config = configFile.substr(configFile.find_last_of("/\\") + 1);

        sprintf(b, " %s %s %s %s %s %s%s --DFF_Config=%s%s --DFF_GName=%s %s 2>&1 %s",
         (isRemote() ? "ssh -T -i ~/opt/fastflow/.ssh/ff_key" : ""),        // -T(Disable pseudo-terminal allocation) -i(File for public key authentication)
         (isRemote() ? host.c_str() : ""),                                  // hostname like json ("endpoint" : "ff@192.168.253.163:8004",) better inserto user@host instead of just host
         (isRemote() ? "'" : ""),                                           // first apex
         this->preCmd.c_str(),                                              // Empty <- probably to fill with LD_LIBRARY_PATH or LD_PRELOAD
         (isRemote() ? "LD_LIBRARY_PATH=~/opt/fastflow/lib" : ""),
         (isRemote() ? "~/opt/fastflow/" : ""),
         (isRemote() ? name_exec.c_str() : executable.c_str()),             // I dont wont an absolute path, better use a standard place(~/opt/fastflow/) or configurable from json
         (isRemote() ? "~/opt/fastflow/" : ""),
         (isRemote() ? name_config.c_str() : configFile.c_str()),           // I dont wont an absolute path, better use a standard place(~/opt/fastflow/) or configurable from json
         this->name.c_str(),                                                // Group form json file
         toBePrinted(this->name) ? "" : "> /dev/null",                      // ?? What about group?
         (isRemote() ? "'" : ""));                                          // second apex

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
