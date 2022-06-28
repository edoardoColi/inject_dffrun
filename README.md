# Inject dff_run
Deployer for "Distributed FastFlow"
  
Execute script "setup.sh" for download all necessary files to act like Master, and specify where is Fastflow and Cereal directory.  
	(FastFlow and Cereal need to be in the same directory.)	#TODO can split into two  
  
Setup parameters inside "setup.sh" in case you need:  
`DEBUG`to enable the debug in Makefile compilation.  
`INJECT`to replace "dff_run.ccp" FastFlow original one with the costumized one.  
`RESTORE`to restore official FastFlow "dff_run.cpp".  
