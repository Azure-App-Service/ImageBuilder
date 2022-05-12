#!/bin/bash

# This script generates Dockerfiles for Kudulite HotPatch Images for Azure App Service on Linux.
#
# --------------------------------
# What are Kudulite HotPatch Images?
# --------------------------------
# Generally we use oryx/build as the base image to build Kudulite images. During a release, 
# oryx/build image remains constant. We only keep updating Kudulite code to take in any fixes.
# To keep the number of unique layers smaller, we use take a HotPatch approach and generate Kudulite HotPatch Images
# We use previous Kudulite image as base image and just build the Kudulite code

set -e

# Current Working Dir
declare -r ORIG_DIR=`pwd`
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Directory for Generated Docker Files
declare -r STACK_NAME="KuduLite"
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r BASE_IMAGE_REPO_NAME="$2/kudulite"
declare -r BASE_IMAGE_VERSION_STREAM_FEED="$3"                     # Base Image Version; Kudulite tag : 20190819.2
declare -r APPSVC_KUDULITE_REPO="$4"        
declare -r CONFIG_DIR="$5"                                         # ${Current_Repo}/Config
declare -r METADATA_FILE="$SYSTEM_ARTIFACTS_DIR/metadata"
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"
declare -r KUDULITE_BRANCH=$6
declare -r APP_SVC_REPO_BRANCH="${KUDULITE_BRANCH:="dev"}"
declare -r DYN_INST_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo-DynInst"
declare -r DYN_INST_REPO_BRANCH="${KUDULITE_BRANCH:="dev"}"


function generateDockerFilesForKuduliteHotPatchImage()
{

    local image_type=$1
    image_type="${image_type:=stretch}" 

    local dockerfile_name="Dockerfile-RP-Main"
    local kudulite_tag=$BASE_IMAGE_VERSION_STREAM_FEED
    local current_version_directory="${APP_SVC_REPO_DIR}/"

    if [ "$image_type" = "buster" ]; then
        dockerfile_name="Dockerfile-RP-Buster"
        kudulite_tag="buster_$BASE_IMAGE_VERSION_STREAM_FEED"
        current_version_directory="$DYN_INST_REPO_DIR"
    fi

    # Example line:
    # use base image as Kudulite - mcr.microsoft.com/appsvc/kudulite:$BASE_IMAGE_VERSION_STREAM_FEED

    # Base Image
    local base_image_name="${BASE_IMAGE_REPO_NAME}:$kudulite_tag"
    
    local target_dockerfile="${current_version_directory}/RolePatcher/$dockerfile_name"
    
    #Rename Dockerfile for kudu
    mv ${target_dockerfile} ${current_version_directory}/Dockerfile

    echo "Generating Dockerfile for HotPatch kudulite image '$base_image_name' in directory '$current_version_directory'..."

    # Replace placeholders, changing sed delimeter since '/' is used in path
    sed -i "s|BASE_IMAGE|$base_image_name|g" "${current_version_directory}/Dockerfile"

    # Register the generated docker files with metadata dir
    echo "${APP_SVC_REPO_DIR}, " > $METADATA_FILE

    echo "Done."

}

function pullAppSvcRepo()
{
    # Create Stretch based Kudulite HotPatch Image 
    echo "Cloning App Service KuduLiteBuild Repository in $APP_SVC_REPO_DIR"
    git clone $APPSVC_KUDULITE_REPO $APP_SVC_REPO_DIR
    cd $APP_SVC_REPO_DIR
    echo "Checking out branch $APP_SVC_REPO_BRANCH"
    git checkout $APP_SVC_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $APP_SVC_REPO_DIR
    echo

    # Create Buster based Kudulite HotPatch Image 
    echo "Cloning App Service KuduLiteBuild Repository in $DYN_INST_REPO_DIR"
    git clone $APPSVC_KUDULITE_REPO $DYN_INST_REPO_DIR
    cd $DYN_INST_REPO_DIR
    echo "Checking out branch $DYN_INST_REPO_BRANCH"
    git checkout $DYN_INST_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $DYN_INST_REPO_DIR
}

pullAppSvcRepo

# Arg 1 : Kudulite Image type
generateDockerFilesForKuduliteHotPatchImage "stretch"
echo
generateDockerFilesForKuduliteHotPatchImage "buster"