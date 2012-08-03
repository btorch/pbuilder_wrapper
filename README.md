pbuilder_wrapper
================

This is a wrapper to be used with pbuilder, deb signing and reprepro. 

Please note that you must first have a proper pbuilder environment setup and also have GPG setup.
If you want to add packes to a repo then you also need to have reprepro properly setup 



Syntax


Syntax
    pbuilder_wrapper.sh  [-v] [-f] [-g GIT_URL[,GIT_URL2]] -t [GIT TAG[,GIT TAG2]] [-c CONFIG_FILE] [-r REPO_NAME]
    -r  Name of the repo for reprepro to add the package(s) into (ubuntu | ubuntu-unstable)
        If none supplied than nothing is added 

    -c  Location of the pbuilder configuration file (if none provided it will try to find one under /etc/pbuilder/)

    -g  Git repo URL where the source is located. If there is no debian within the source repo then provide 
        the primary repo + the repo where the debian contents should be cloned from.
        e.g: -g git://github.com/btorch/myproject.git,git://github.com/btorch/myproject_debian.git

    -t  If you would like to provide a branch/tag number for the git repo. If you are giving two git repos
        with the -g flag than you can do the same here, e.g: -t "tag1,tag2" 

    -s  Sign the debian packages with the GPG key id provided 
        If this flag is omitted it will try to sign the packages with the key assigned to the PGPKEY Variable

    -f  Skip asking to proceed with the building and just go for it

    -v  For verbose mode duing package build 

    -h  For this usage screen  

    Info:
        if you are using the "-g" flag and providing the git repo(s), then you can run the script over SSH without
        having to login to the box. If the flag is not provided then you would run the script from the pbuilder system 
        as shown below: 

        $ cd /home/myname/myproject 
        $ pbuilder_wrapper.sh -f -r RepoName -c ConfigFile"

        Over SSH 
        $ ssh user@pbuilder.dom.com 'pbuilder_wrapper.sh -f -g "GIT_URL"  -r REPO_NAME -c CONFIG_FILE'

        Please also note that a "debian" directory with the proper debain packaging configs must exist
        You can also specify the -r flag for adding the packages to a repo if you have one setup 




