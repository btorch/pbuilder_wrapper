#!/bin/bash

# Author: Marcelo Martins
# Date: 2012-07-21
# Version: 1.00
#
# Info:
#       A wrapper for building, signing and adding packages to a repo. 
#




##############################
# INITIALIZING SOME VARIABLE
##############################
# Change the variables below as you see fit
#
PBUILDERRC_FIND=1

PDEBUILD="/usr/bin/pdebuild"
DPKGSIG="/usr/bin/dpkg-sig"
REPREPRO="/usr/bin/reprepro"

GIT="/usr/bin/git"
GPG="/usr/bin/gpg"
# Please change this to be your PGP key id 
GPGKEY="2E2AB11B"
REPO_DOMAIN="packages.racklabs.com"

PBUILDERRC_LOCATION="/etc/pbuilder/"
BUILD_RESULT_BASE="/var/cache/pbuilder/result"

# REPO BASE
# This is the location where the repos have been created
# Please change it according to your setup  
REPREPRO_BASEDIR="/srv/packages"



# ARGUMENTS 
#NUMBER_OF_ARGS=$#
#ARG_SARRAY=("$@")
#ARGS=$@




##############################
# USAGE & GETOPTS
##############################

usage_display (){
cat << USAGE

Syntax
    pbuilder_wrapper.sh  [-f] [-g GIT_URL] [-c CONFIG_FILE] [-r REPO_NAME]
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

USAGE
exit 1
}


while getopts "hvsfr:c:g:" opts
do 
    case $opts in 
        r) 
            REPO_NAME="${OPTARG}"
            ;;
        c)
            PBUILDERRC="${OPTARG}"
            PBUILDERRC_FIND=0
            ;;
        g)
            URL="${OPTARG}"
            CK=","
            if [[ $URL =~ $CK ]]; then 
                GIT_URL=`echo $URL | cut -d "," -f 1`
                GIT_URL2=`echo $URL | cut -d "," -f 2`
            else 
                GIT_URL="$URL"
            fi 
            ;;
        t)
            TAGS="${OPTARG}"
            CK=","
            if [[ $TAGS =~ $CK ]]; then 
                TAG1=`echo $TAGS | cut -d "," -f 1`
                TAG2=`echo $TAGS | cut -d "," -f 2`
            else 
                TAG1="$TAGS"
            fi 
            ;;
        s)
            GPGKEY_PROVIDED="${OPTARG}"
            ;;
        f)
            SKIP_ASKING="true"
            ;;
        v)
            VERBOSE="true"
            ;;
       \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
        h)
            usage_display
            ;;
        *) 
            usage_display
            ;;
    esac     
done




#####################
# FUNCTIONS SECTION
#####################

start_banner (){

    printf "\n"
    printf "\n\t #######################################################"
    printf "\n\t #                PBUILDER WRAPPER                     #" 
    printf "\n\t #######################################################"
    printf "\n\t # "  
    printf "\n\t #   Project Name : %s " "$PROJECT"
    printf "\n\t #   Project Version : %s " "$VERSION"
    printf "\n\t #   Debian Revision : %s " "$DEBREV"
    printf "\n\t #   Debian Distro : %s " "$DISTRO"
    printf "\n\t # "
    printf "\n\t #   Build ID : %s " "$BUILD_ID"
    printf "\n\t #   Build Config : %s " "$PBUILDERRC_FILE"
    printf "\n\t #   Build Result : %s" "$BUILDRESULT" 
    printf "\n\t #   Work Location : %s " "$TEMPDIR/source"
    printf "\n\t # "
    if [[ ! -z "$GIT_URL" ]]; then  
        printf "\n\t #   GIT URL : $GIT_URL "
        if [[ ! -z "$TAG1" ]]; then  
            printf "\n\t #   GIT Tag : $TAG1 "
        fi
        printf "\n\t # "
    fi 
    printf "\n\t # \n"

}


end_banner (){

    printf "\n\t # "  
    printf "\n\t #   Project Name : %s " "$PROJECT"
    printf "\n\t #   Project Version : %s " "$VERSION"
    printf "\n\t #   Debian Revision : %s " "$DEBREV"
    printf "\n\t #   Debian Distro : %s " "$DISTRO"
    printf "\n\t # "
    printf "\n\t #   Build ID : %s " "$BUILD_ID"
    printf "\n\t #   Build Config : %s " "$PBUILDERRC_FILE"
    printf "\n\t #   Build Result : %s" "$BUILDRESULT" 
    printf "\n\t #   Work Location : %s " "$TEMPDIR/source  (cleaned)"
    printf "\n\t # "
    if [[ ! -z "$REPO_NAME" ]]; then 
        printf "$repo_msg"
    fi 
    printf "\n\t # "
    printf "\n\t #######################################################"
    printf "\n\t #                PBUILDER WRAPPER                     #" 
    printf "\n\t #######################################################"
    printf "\n\n"
}


do_not_proceed_banner (){
    printf "\n\t # "
    printf "\n\t # Exiting ... "
    printf "\n\t #######################################################"
    printf "\n\t #                PBUILDER WRAPPER                     #" 
    printf "\n\t #######################################################"
    printf "\n\n"
}


pdebuild_error (){
    printf "\n\t # "  
    printf "\n\t #   BUILD FAILED ... "  
    printf "\n\t #   Project Name : %s " "$PROJECT"
    printf "\n\t #   Project Version : %s " "$VERSION"
    printf "\n\t #   Debian Revision : %s " "$DEBREV"
    printf "\n\t #   Debian Distro : %s " "$DISTRO"
    printf "\n\t # "
    printf "\n\t #   Please review the build log under the build result directory"
    printf "\n\t #   Build Result : %s" "$BUILDRESULT"
    printf "\n\t # "
    printf "\n\t #######################################################"
    printf "\n\t #                PBUILDER WRAPPER                     #"
    printf "\n\t #######################################################"
    printf "\n\n"

    clean_up
    exit 1
}


clean_up (){
    rm -rf $TEMPDIR
}


setup_workspace () {

    USER=$(whoami)
    BUILD_ID=$(date +"%Y-%m-%d_%T")

    # Create a temp location where the files will be moved to and worked on
    TEMPDIR=$(mktemp -d)
    mkdir -p $TEMPDIR/source 
    if [[ $? -ne 0 ]]; then 
        printf "\n\t Unable to create $TEMPDIR/source directory \n"
        exit 1 
    fi 


    # If a git url is provided than try to retrieve it 
    if [[ ! -z $GIT_URL ]]; then 
        cd $TEMPDIR/source
        PROJECT=$(basename "$GIT_URL" | sed 's/.git//')
        $GIT clone -q "$GIT_URL" $PROJECT
        WORKSPACE="$TEMPDIR/source/$PROJECT"

        if [[ ! -z $TAG1 ]]; then 
            cd $WORKSPACE
            $GIT checkout -b $TAG1 $TAG1 
            cd ..
        fi 

        if [[ ! -z $GIT_URL2 ]]; then 
            cd $WORKSPACE
            $GIT clone -q "$GIT_URL2" debian    
            if [[ ! -z $TAG2 ]]; then 
                cd debian
                $GIT checkout -b $TAG2 $TAG2 
                cd ..
            fi 
        fi
    else
       WORKSPACE=$(pwd)
       PROJECT=$(basename $WORKSPACE)
    fi 
 
    cd $WORKSPACE                
    if [[ ! -e $WORKSPACE/debian ]]; then
        printf "\n\t No debian folder found within your project root " 
        printf "\n\t $WORKSPACE/debian Not Found \n\n" 
        exit 1 
    fi


    # Grab some info by parsing the changelog file
    NAME=$(dpkg-parsechangelog | grep "Source" | tr -d ' ' | cut -d ":" -f 2)
    VERSION=$(dpkg-parsechangelog | grep "Version" | tr -d ' ' | cut -d ":" -f 2 | cut -d '-' -f 1)
    DEBREV=$(dpkg-parsechangelog | grep "Version" | tr -d ' ' | cut -d ":" -f 2 | cut -d '-' -f 2)
    DISTRO=$(dpkg-parsechangelog | grep "Distribution" | tr -d ' ' |  cut -d ":" -f 2)


    # Check on pdebuilder config file 
    # If none is provided try to locate one
    if [[ $PBUILDERRC_FIND -eq 0 ]]; then 
        PBUILDERRC_FILE="$PBUILDERRC"
        if [[ ! -e "$PBUILDERRC_FILE" ]]; then 
            printf "\n\t Config %s not found " "$PBUILDERRC_FILE"
            printf "\n\t Make sure the config exists \n"
            exit 1
        fi  
    else
        printf "\n\t No pbuilder config provided, "
        read -p " locate one (y/n) ?  " key
        if [[ $key = "y" ]]; then 
            locate_pbuilderrc_file $NAME $DISTRO
        else
            printf "\t Please provide pbuilder config or let me locate one \n\n"
            exit 1 
        fi 
    fi    


    # Create the location where the build result will go too
    BUILDRESULT=$BUILD_RESULT_BASE"/"$USER"/"$PROJECT"/"$BUILD_ID
    mkdir -p $BUILDRESULT
    if [[ $? -ne 0 ]]; then 
        printf "\n\t Unable to create $BUILDRESULT directory \n"
        exit 1 
    fi 

}


check_gpg_keys (){

    $GPG --list-keys | grep $GPGKEY  > /dev/null
    if [[ $? -ne 0 ]]; then 
        printf "\n\t GPG Public Key not found \n"
        rmdir $BUILDRESULT
        rm -rf $TEMPDIR        
        exit 1
    fi 

    $GPG --list-sigs | grep $GPGKEY  > /dev/null
    if [[ $? -ne 0 ]]; then 
        printf "\n\t GPG Sig not found \n"
        rmdir $BUILDRESULT
        rm -rf $TEMPDIR        
        exit 1
    fi 

    $GPG -K | grep $GPGKEY  > /dev/null
    if [[ $? -ne 0 ]]; then 
        printf "\n\t GPG Secrete Key not found \n"
        rmdir $BUILDRESULT
        rm -rf $TEMPDIR        
        exit 1
    fi 

}


locate_pbuilderrc_file (){

    SOURCE_NAME=$1
    DEB_DISTRO=$2
    PBUILDERRC_FILE=$(find /etc/pbuilder/ -type f -iname "*$DEB_DISTRO*$SOURCE_NAME*")

    if [[ -z $PBUILDERRC_FILE ]]; then 
        printf "\n\t Could not find a PBUILDER config for this specific project. "
        printf "\n\t I will try to use the base config but if it doesn't work seek support "
 
        PBUILDERRC_FILE="/etc/pbuilder/pbuilderrc_"$DEB_DISTRO"-amd64"    
        if [[ ! -e $PBUILDERRC_FILE ]]; then 
            printf "\n\t Config $PBUILDERRC_FILE not found "
            exit 1
        fi 
    fi
}


start_build  (){

    printf "\n\t ---------------------- Starting build process ---------------------- \n"
    sleep 5 

    # Checking on GPG
    check_gpg_keys

    # Making a copy 
    if [[ -z "$GIT_URL" ]]; then 
        rsync -aq0c  $WORKSPACE $TEMPDIR/source/    
    fi 

    # Get into the temp location where the source is located 
    cd $TEMPDIR/source

    # Change directory to follow debian naming scheme 
    if [[ ! $PROJECT = $NAME-$VERSION ]]; then 
        mv $PROJECT $NAME-$VERSION
    fi 

    # Creating debian original tarball without .git or debian files
    printf "\n\t - Creating original tarball : %s_%s.orig.tar.gz  " "$NAME" "$VERSION"
    /bin/tar --exclude=".git" --exclude="debian" -zcf "$NAME"_"$VERSION".orig.tar.gz $NAME-$VERSION

    cd $NAME-$VERSION/
    echo -e "\n\t - Starting deb building step \n"
    if [[ ! -z $VERBOSE && $VERBOSE = "true" ]]; then 
        $PDEBUILD --configfile $PBUILDERRC_FILE --buildresult $BUILDRESULT --auto-debsign --debsign-k $GPGKEY 
    else
        $PDEBUILD --configfile $PBUILDERRC_FILE --buildresult $BUILDRESULT --auto-debsign --debsign-k $GPGKEY &> /dev/null
    fi 

    if [[ $? -ne 0 ]]; then 
        pdebuild_error
    fi 

    cd ..
    find ./ -type f -iname "*.build" -exec cp -f {} $BUILDRESULT"/{}" \;

    printf "\n\t ---------------------- Ending build process ---------------------- \n"


    printf "\n\t ---------------------- Starting Package signing ---------------------- \n"
    sign_debs
    printf "\n\t ---------------------- Ending Package signing ---------------------- \n"


    if [[ ! -z $REPO_NAME ]]; then 
        check_repo $REPO_NAME
        printf "\n\t ---------------------- Adding Package(s) to repo ($REPO_NAME) ---------------------- \n"
        add_to_repo
        printf "\n\t ---------------------- Package(s) added to repo ($REPO_NAME) ---------------------- \n"
    fi 
    
}


sign_debs () { 
    # Signing Packages with GPG KEY 
    if [[ ! -z $GPGKEY_PROVIDED ]]; then 
        GPGKEY="$GPGKEY_PROVIDED"
    fi 

    cd $BUILDRESULT
    DEB_FILES=$(find . -name "*.deb" | sed 's/\.\///')
    for i in "$DEB_FILES" 
    do 
      $DPKGSIG -k $GPGKEY --sign builder $i
    done
}


check_repo (){
    # Check that the location of the repo actually exists first
    NAME=$1
    BASEDIR=$REPREPRO_BASEDIR"/"$NAME
    if [[ ! -e $BASEDIR ]]; then 
        printf "\n\t # Location for the repo could not be found "
        printf "\n\t # Please check that $BASEDIR exists "
        do_not_proceed_banner
        clean_up
        exit 1
    fi 
}


add_to_repo (){ 
    # Removes old packages to avoid hash mismatches and then add package to the repo
    # The user must have sudo privileges or the group r/w access to the repo

    cd $BUILDRESULT
    BASEDIR=$REPREPRO_BASEDIR"/"$NAME 
    DEB_FILES=$(find . -name "*.deb" | sed 's/\.\///')
    for x in "$DEB_FILES" 
    do 
        PKGNAME=`printf "%s" "$x" | cut -d "_" -f 1`
        sudo $REPREPRO --basedir $BASEDIR remove $DISTRO $PKGNAME 2> /dev/null
        sudo $REPREPRO --basedir $BASEDIR includedeb $DISTRO $x 2> /dev/null
    done

    repo_msg="\n\t #   Packages added to repo: deb http://$REPO_DOMAIN/$REPO_NAME $DISTRO main " 
    for x in ${DEB_FILES}
    do 
        repo_msg="${repo_msg}\n\t # \t $x "
    done
    
}


################## 
# MAIN SECTION
##################

setup_workspace

start_banner

if [[ $SKIP_ASKING = "true" ]]; then 
    start_build
else 
    printf "\n\t Should we proceed with the build "
    read -p " (y/n) ?  " choice
    if [[ $choice = "y" ]]; then 
        start_build
    else 
        rmdir $BUILDRESULT
        do_not_proceed_banner
        clean_up
        exit 0
    fi 
fi 

end_banner
clean_up

exit 0 


