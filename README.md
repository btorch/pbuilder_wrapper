pbuilder_wrapper
================

This is a wrapper to be used with pbuilder, deb signing and reprepro. 

Please note that you must first have a proper pbuilder environment setup and also have GPG setup.
If you want to add packes to a repo then you also need to have reprepro properly setup 



Syntax

    pbuilder_wrapper.sh  -d PROJECT [-c CONFIG_FILE] [-r REPO_NAME] [-s GPGKEY]

    -r  Name of the repo for reprepro to add the package(s) into 
        If none supplied than nothing is added (NOT YET IMPLEMENTED)

    -c  Location of the pbuilder configuration file (if none provided it will try to find one under /etc/pbuilder/)

    -d  Name of the directory where the source (aka. your project) is located. (A debian folder must exist within it)

    -s  Sign the debian packages with the GPG key id provided
        If this flag is omitted it will try to sign the packages with the key assigned to the PGPKEY Variable

    Info:
        Your PROJECT must be located within the directory you are calling the script from
        e.g: /home/myname/myproject
             Then I will run the script from  /home/myname as "pbuilder_wrapper.sh -d myproject -c ConfigFile"
             Please also note that a "debian" directory with the proper debain packaging configs must exist


