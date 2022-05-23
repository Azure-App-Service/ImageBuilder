#!/bin/bash
# --------------------------------------------------------------------------------------------
# This script builds Runtime Docker Images for all stacks on Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

# Directory for Generated Docker Files
declare -r SYSTEM_ARTIFACTS_DIR="$1"            # drop/ - when called from devops ; ../../output - when called from local
declare -r APP_SVC_BRANCH_PREFIX="$2"           # appsvc, appsvctest
declare -r CONFIG_DIR="$3"                      # src/{stack_name}/
declare -r PIPELINE_BUILD_NUMBER="$4"           # tag of the image being built
declare -r STACK="$5"                           # e.g. node, python, dotnet
declare -r BUILD_REASON="$6"                    
declare -r STACK_VERSION_TO_BUILD="$7"

declare -r WAWS_IMAGE_REPO_NAME="wawsimages.azurecr.io"
declare -r ACR_BUILD_IMAGES_ARTIFACTS_FILE="$SYSTEM_ARTIFACTS_DIR/builtImages.txt"
declare -r DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# In Image Builder v1, we were building and pushing images to MCR and in the later steps were testing the image
# In v2 version, we want to avoid this. So we build the images, run a script that can test images and 
# if they pass use another script to push images to MCR.
declare -r LIST_OF_IMAGES_TO_PUSH_TO_MCR="${STACK}_LIST_OF_IMAGES_TO_PUSH_TO_MCR"

# Summary :
# This function displays message in the following format
# Message
# ----------------------
#
# Arguments :
# 1 : message
function display_message()
{
    local message=$1
    echo "$message"
    echo "--------------------------"
}

# Summary :
# This function displays all files in artifacts directory.
# artifacts directory is drop/ - when called from devops ; ../../output - when called from local
#
# Arguments :
# 1 : artifacts_directory
function display_files_in_artifacts_directory()
{
    local artifacts_directory=$1
    display_message "Listing artifacts dir :"
    ls $artifacts_directory
    echo 
}

# Summary :
# This function displays all files in src/<stack> directory 
#
# Arguments :
# 1 : stack_directory
function display_files_in_stack_directory()
{
    local stack_directory=$1
    display_message "Listing stacks dir :"
    ls $stack_directory
    echo 
}
# Summary :
# This function displays information regarding image to be built
#
# Arguments :
# 1 : tag
# 2 : docker_file_path
function display_information_regarding_image_to_be_built()
{
    local tag=$1
    local docker_file_path=$2
    display_message "Building test image with "
    echo "Tag           : $tag "
    echo "DockerFile    : $docker_file_path"
    echo
}

# Summary :
# This function helps in clearing the file that contains the list of images that must be pushed to MCR
#
# Arguments :
function clean_list_of_images_to_push_to_mcr()
{
    rm -f $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR
}

# Summary :
# This function helps to build the runtime images for Azure App Service Linux
#
# Arguments :
# 
function build_runtime_images() 
{
    if [ -f "$CONFIG_DIR/versionTemplateMap.txt" ]; then
        clean_list_of_images_to_push_to_mcr

        while IFS=, read -r STACK_VERSION BASE_IMAGE STACK_VERSION_TEMPLATE_DIR STACK_TAGS || [[ -n $STACK_VERSION ]] || [[ -n $BASE_IMAGE ]] || [[ -n $STACK_VERSION_TEMPLATE_DIR ]] || [[ -n $STACK_TAGS ]]
        do
            # if STACK_VERSION_TO_BUILD is empty (not specified) or STACK_VERSION_TO_BUILD == STACK_VERSION
            if [[ -z $STACK_VERSION_TO_BUILD || $STACK_VERSION_TO_BUILD == $STACK_VERSION ]];
            then
                IFS='|' read -ra STACK_TAGS_ARR <<< "$STACK_TAGS"
                for TAG in "${STACK_TAGS_ARR[@]}"
                do

                    # Modify the stack name as needed
                    local stack_modifed_name=$STACK
                    if [[ $STACK = "php-xdebug" ]]
                    then
                        stack_modifed_name="php"
                    fi

                    if [[ $STACK = "wordpress" ]]
                    then
                        stack_modifed_name="wordpress-alpine-php"
                    fi

                    local TAG_MOD="${TAG}_${PIPELINE_BUILD_NUMBER}"
                    if [[ $STACK = "wordpress" && ( $TAG = "latest"  ||  $TAG = "latest_7.4" || $TAG = "stable" || $TAG =~ ^stage[0-9]$ ) ]]; then
                        echo "INFO: updating $TAG tag"
                        TAG_MOD="${TAG}"
                    fi

                    # MCR and WAWSimages acr follow different naming convention.
                    # For MCR : mcr.microsoft.com/public/appsvc/<stack>:<tag>
                    local mcr_tag_in_upper_case="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${stack_modifed_name}:${TAG_MOD}"
                    local mcr_tag_in_lower_case="${mcr_tag_in_upper_case,,}"

                    # For WAWSimages : wawsimages.microsoft.com/appsvc/<stack>:<tag>
                    local wawsimages_acr_tag_name_in_upper_case="${WAWS_IMAGE_REPO_NAME}/${stack_modifed_name}:${TAG_MOD}"
                    local wawsimages_acr_tag_name_in_lower_case="${wawsimages_acr_tag_name_in_upper_case,,}"

                    local runtime_image_docker_file_path="Dockerfile"

                    display_files_in_artifacts_directory "${SYSTEM_ARTIFACTS_DIR}"
                    display_files_in_stack_directory "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}"                    
                    display_information_regarding_image_to_be_built $wawsimages_acr_tag_name_in_lower_case $runtime_image_docker_file_path

                    cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}"

                    # Build Runtime Images:
                    # php-xdebug depends of published images
                    if [ "$BUILD_REASON" != "PullRequest" ] || [ "$STACK" != "php-xdebug" ]; then
                        echo docker build -t "$wawsimages_acr_tag_name_in_lower_case" -f "$runtime_image_docker_file_path" .
                        docker build -t "$wawsimages_acr_tag_name_in_lower_case" -f "$runtime_image_docker_file_path" .

                    elif [ "$BUILD_REASON" != "PullRequest" ] && [ "$STACK" == "php-xdebug" ]; then
                        # poll until php image is published
                        BASE_TAG=`head -n 1 Dockerfile | sed 's/FROM //g'`
                        PULL_OUTPUT=`docker pull $BASE_TAG`
                        LOOP_COUNTER=0;
                        while [[ $PULL_OUTPUT != *"up to date"* ]] && [ $LOOP_COUNTER -le 60 ]; do
                            sleep 1m
                            PULL_OUTPUT=$(docker pull $BASE_TAG)
                            LOOP_COUNTER=$LOOP_COUNTER+1
                        done;
                        echo docker build -t "$wawsimages_acr_tag_name_in_lower_case" -f "$runtime_image_docker_file_path" .
                        docker build -t "$wawsimages_acr_tag_name_in_lower_case" -f "$runtime_image_docker_file_path" .
                    fi

                    docker tag $wawsimages_acr_tag_name_in_lower_case $mcr_tag_in_lower_case
                    
                    echo $mcr_tag_in_lower_case >> $SYSTEM_ARTIFACTS_DIR/${STACK}builtImageList

                    echo $wawsimages_acr_tag_name_in_lower_case >> $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR
                    echo $mcr_tag_in_lower_case >> $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR
                done
            fi
            
        done < "$CONFIG_DIR/versionTemplateMap.txt"
    fi
}

build_runtime_images