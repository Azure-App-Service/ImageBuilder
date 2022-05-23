#!/bin/bash
# --------------------------------------------------------------------------------------------
# This script generates Dockerfiles for Kudulite Images for Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

declare -r DIRECTORY_FROM_WHICH_THIS_FILE_IS_CALLED="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

declare -r SYSTEM_ARTIFACTS_DIR="$1"                                    # drop/ - when called from devops ; ../../output - when called from local
declare -r APPSVC_KUDULITE_REPO="$2"        

kudulite_branch=$3
declare -r APPSVC_KUDULITE_BRANCH="${kudulite_branch:="dev"}"

declare -r APPSVC_KUDULITE_TYPE=$4                                      # debian flavour of Kudu ( stretch / buster / bullseye)
declare -r BASE_IMAGE_REPO_NAME="$5/build"                              # mcr.microsoft.com/oryx/build
declare -r ORYX_TAG="$6"                                                # Base Image Version; Oryx Version : 20190819.2

declare -r APPSVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/kudulite/GitRepo"
declare -r METADATA_FILE="$SYSTEM_ARTIFACTS_DIR/metadata"               # has value of APPSVC_REPO_DIR. This file will be removed soon.

# In Image Builder v1, we were building and pushing images to MCR and in the later steps were testing the image
# In v2 version, we want to avoid this. So we build the images, run a script that can test images and 
# if they pass use another script to push images to MCR.
declare -r LIST_OF_IMAGES_TO_PUSH_TO_MCR="kudulite_LIST_OF_IMAGES_TO_PUSH_TO_MCR"

# Summary :
# Replaces BASE_IMAGE_NAME_PLACEHOLDER in Dockerfile with mcr.microsoft.com/oryx/build:<tag>
#
# Arguments :
# 1 : kudulite_type
function update_oryx_tag()
{
    local kudulite_type=$1
    echo "kudulite_type : $kudulite_type"
    local dockerfile_name_as_in_kudulite_repo="Dockerfile-Main"
    local oryx_tag=$ORYX_TAG

    if [[ $kudulite_type == "buster" ]]; then
        dockerfile_name_as_in_kudulite_repo="Dockerfile-Buster"
        oryx_tag="github-actions-buster-$ORYX_TAG"
    fi

    if [[ $kudulite_type == "bullseye" ]]; then
        dockerfile_name_as_in_kudulite_repo="Dockerfile-Bullseye"
        oryx_tag="github-actions-bullseye-$ORYX_TAG"
    fi

    local base_image_name="${BASE_IMAGE_REPO_NAME}:$oryx_tag"
    local current_version_directory="${APPSVC_REPO_DIR}/${kudulite_type}"    
    local target_dockerfile="${current_version_directory}/Dockerfile"

    # Renaming Dockerfile-Main/Dockerfile-Buster/Dockerfile-Bullseye to Dockerfile
    mv ${current_version_directory}/$dockerfile_name_as_in_kudulite_repo ${current_version_directory}/Dockerfile

    echo "Updating oryx base image tag to '$base_image_name' in directory '$current_version_directory'..."
    sed -i "s|BASE_IMAGE_NAME_PLACEHOLDER|$base_image_name|g" "$target_dockerfile"

    echo "${APPSVC_REPO_DIR}, " > $METADATA_FILE

    echo "Done."
}

# Summary :
# This functon is used to clone kudulite repo to a folder nameed default
#
# Arguments :
function clone_kudulite_repo()
{
    local default_folder_name="default"
    chmod u+x $DIRECTORY_FROM_WHICH_THIS_FILE_IS_CALLED/clone_kudulite_repo.sh
    $DIRECTORY_FROM_WHICH_THIS_FILE_IS_CALLED/clone_kudulite_repo.sh $SYSTEM_ARTIFACTS_DIR $APPSVC_KUDULITE_REPO $APPSVC_KUDULITE_BRANCH $default_folder_name
}

# Summary : 
# When compared to v1 version of Image Builder, this behaviour is changes
# in v1, we were cloning the same repository multiple times.
# in v2, we clone the repo once to a folder called default and then copy the contents to folders like stretch, buster etc.
#
# Arguments :
# 1 : kudulite_type
function create_copy_of_cloned_kudulite_repo()
{
    local kudulite_type=$1
    mkdir -p $APPSVC_REPO_DIR/$kudulite_type
    cp -R $APPSVC_REPO_DIR/default/. $APPSVC_REPO_DIR/$kudulite_type
}

clone_kudulite_repo "default"

# if kudulite type is not specified, generate dockerfiles for all types of kudulite
if [[ -z $APPSVC_KUDULITE_TYPE ]]; then
   create_copy_of_cloned_kudulite_repo "stretch"
   update_oryx_tag "stretch"

   create_copy_of_cloned_kudulite_repo "buster"
   update_oryx_tag "buster"

   create_copy_of_cloned_kudulite_repo "bullseye"
   update_oryx_tag "bullseye"

   exit
fi

# Generate Dockerfile for specified type of kudulite
create_copy_of_cloned_kudulite_repo $APPSVC_KUDULITE_TYPE
update_oryx_tag $APPSVC_KUDULITE_TYPE