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

ADD_TO_REPO=0
PBUILDERRC_FIND=1

PDEBUILD="/usr/bin/pdebuild"
DPKGSIG="/usr/bin/dpkg-sig"
REPREPRO="/usr/bin/reprepro"

GPG="/usr/bin/gpg"
RACKLABS_GPGKEY="2E2AB11B"

GIT="/usr/bin/git"

#PBUILDERRC_FILE="/etc/pbuilder/pbuilderrc_lucid-sos-amd64"
PBUILDERRC_LOCATION="/etc/pbuilder/"
BUILD_RESULT_BASE="/var/cache/pbuilder/result"


# REPO BASES
REPREPRO_BASEDIR_UNSTABLE="/srv/packages/ubuntu-unstable"
REPREPRO_BASEDIR_STABLE="/srv/packages/ubuntu"



# ARGUMENTS 
NUMBER_OF_ARGS=$#
ARG_SARRAY=("$@")
ARGS=$@





##############################
# USAGE & GETOPTS
##############################

usage_display (){
cat << USAGE

Syntax
    pbuilder_wrapper.sh  -d PROJECT [-c CONFIG FILE LOCATION] [-r REPO NAME]
    -r  Name of the repo for reprepro to add the package(s) to (If none supplied than nothing is added) [NOT YET IMPLEMENTED]
    -c  Location of the pbuilder configuration file (if none provided it will try to find one under /etc/pbuilder/)
    -d  Name of the directory where the source (aka. your project) is located. (A debian folder must exist within it)
    -h  For this usage screen  

    Info: 
        Your PROJECT must be located within the directory you are calling the script from 
        e.g: /home/myname/myproject 
             Then I will run the script from  /home/myname as "pbuilder_wrapper.sh -d myproject -c ConfigFile
             Please also note that a "debian" directory with the proper debain packaging configs must exist

USAGE
exit 1
}


while getopts "hrc:d:" opts
do 
    case $opts in 
        r) 
            REPO_NAME="${OPTARG}"
            ADD_TO_REPO=1
            ;;
        c)
            PBUILDERRC="${OPTARG}"
            PBUILDERRC_FIND=0
            ;;
        d)
            PROJECT="${OPTARG}"
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
    printf "\n\t #######################################################"
    printf "\n\t #                PBUILDER WRAPPER                     #" 
    printf "\n\t #######################################################"
    printf "\n\n"

}

clean_up (){

    rm -rf $TEMPDIR

}

setup_workspace () {

    USER=$(whoami)
    BUILD_ID=$(date +"%Y-%m-%d_%T")
    WORKSPACE=$(pwd)
   
    if [[ ! -e $WORKSPACE/$PROJECT ]]; then 
        printf "\n\t You must be on the wrong directory level"   
        printf "\n\t Can't find $WORKSPACE/$PROJECT \n\n "  
        exit 1  
    else
        cd $WORKSPACE/$PROJECT
    fi 


    if [[ ! -e debian ]]; then
        printf "\n\t No debian folder found within your project root \n\n" 
        exit 1 
    fi

    # Grab some info by parsing the changelog file
    NAME=$(dpkg-parsechangelog | grep "Source" | tr -d ' ' | cut -d ":" -f 2)
    VERSION=$(dpkg-parsechangelog | grep "Version" | tr -d ' ' | cut -d ":" -f 2 | cut -d '-' -f 1)
    DEBREV=$(dpkg-parsechangelog | grep "Version" | tr -d ' ' | cut -d ":" -f 2 | cut -d '-' -f 2)
    DISTRO=$(dpkg-parsechangelog | grep "Distribution" | tr -d ' ' |  cut -d ":" -f 2)

    cd $WORKSPACE


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
    # Should be /var/cache/pbuilder/result/USERNAME/BUILD_ID/PROJECT
    BUILDRESULT=$BUILD_RESULT_BASE"/"$USER"/"$PROJECT"/"$BUILD_ID
    mkdir -p $BUILDRESULT
    if [[ $? -ne 0 ]]; then 
        printf "\n\t Unable to create $BUILDRESULT directory \n"
        exit 1 
    fi 


    # Create a temp location where the files will be moved to and worked on
    TEMPDIR=$(mktemp -d)
    mkdir -p $TEMPDIR/source 
    if [[ $? -ne 0 ]]; then 
        printf "\n\t Unable to create $TEMPDIR/source directory \n"
        exit 1 
    fi 

}


check_gpg_keys (){

    $GPG --list-keys | grep $RACKLABS_GPGKEY  > /dev/null
    if [[ $? -ne 0 ]]; then 
        printf "\n\t GPG Public Key not found \n"
        rmdir $BUILDRESULT
        rm -rf $TEMPDIR        
        exit 1
    fi 

    $GPG --list-sigs | grep $RACKLABS_GPGKEY  > /dev/null
    if [[ $? -ne 0 ]]; then 
        printf "\n\t GPG Sig not found \n"
        rmdir $BUILDRESULT
        rm -rf $TEMPDIR        
        exit 1
    fi 

    $GPG -K | grep $RACKLABS_GPGKEY  > /dev/null
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
    rsync -aq0c  $WORKSPACE/$PROJECT $TEMPDIR/source/    

    # Get into the temp location where the source is located 
    cd $TEMPDIR/source

    # Change directory to follow debian naming scheme 
    mv $PROJECT $NAME-$VERSION

    # Creating debian original tarball without .git or debian files
    printf "\n\t - Creating original tarball : %s_%s.orig.tar.gz  " "$NAME" "$VERSION"
    /bin/tar --exclude=".git" --exclude="debian" -zcf "$NAME"_"$VERSION".orig.tar.gz $NAME-$VERSION

    cd $NAME-$VERSION/
    echo -e "\n\t - Starting deb building step \n"
    $PDEBUILD --configfile $PBUILDERRC_FILE --buildresult $BUILDRESULT --auto-debsign --debsign-k $RACKLABS_GPGKEY

    cd ..
    find ./ -type f -iname "*.build" -exec cp -f {} $BUILDRESULT"/{}" \;

    printf "\n\t ---------------------- Ending build process ---------------------- \n"

}


#sign_debs () { }


#add_to_repo (){ }


################## 
# MAIN SECTION
##################



setup_workspace

start_banner

printf "\n\t Should we proceed with the build "
read -p " (y/n) ?  " choice
if [[ $choice = "y" ]]; then 
    start_build
else 
    rmdir $BUILDRESULT
fi 

end_banner

clean_up
