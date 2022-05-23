#!/bin/bash
# --------------------------------------------------------------------------------------------
# This script builds the Dockerfiles generated into Kudulite Docker Image
# Note: generate_Dockerfiles_for_kudulite_images.sh should be run before executing this script
# --------------------------------------------------------------------------------------------

declare -r SYSTEM_ARTIFACTS_DIR="$1"            # drop/ - when called from devops ; ../../output - when called from local
declare -r APP_SVC_BRANCH_PREFIX="$2"           # appsvc, appsvctest
declare -r BUILD_REASON="$3"                    # https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml#build-variables-devops-services
declare -r TAG_OF_IMAGE_BEING_BUILT="$4"        # eg. buster_<tag>
declare -r KUDULITE_TYPE_TO_BUILD=$5            # debian flavour of Kudu ( stretch / buster / bullseye)

declare -r STACK="kudulite"
declare -r WAWS_IMAGE_REPO_NAME="wawsimages.azurecr.io"

# Summary :
# This function helps in clearing the file that contains the list of images that must be pushed to MCR
#
# Arguments :
function clean_list_of_images_to_push_to_mcr()
{
    rm -f $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR
}

# Summary : 
# This function helps in building the kudulite image
#
# Arguments 
# 1 : kudulite_type
function build_kudulite_image()
{
    local kudulite_type=$1
    echo "Building Kudulite $kudulite_type based image"

    local image_tag="${kudulite_type}_${TAG_OF_IMAGE_BEING_BUILT}"

    if [[ $kudulite_type == "stretch" ]]; then
        # keeping the tag name consistent with Image builder v1
        # for stetch based kudu the take name will be just the build number
        # e.g mcr.microsoft.com/appsvc/kudulite:<tag>
        image_tag="${TAG_OF_IMAGE_BEING_BUILT}"
    fi

    local wawsimages_acr_tag_name_in_upper_case="${WAWS_IMAGE_REPO_NAME}/${STACK}:$image_tag"
    # Converting to lower case as MCR doesn't support characters in uppercase
    local wawsimages_acr_tag_name_in_lower_case="${wawsimages_acr_tag_name_in_upper_case,,}"

    local mcr_tag_in_upper_case="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${STACK}:$image_tag"
    local mcr_tag_in_lower_case="${mcr_tag_in_upper_case,,}"

    local kudulite_image_docker_file_path="Dockerfile"
    cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${kudulite_type}"

    docker build -t "$wawsimages_acr_tag_name_in_lower_case" -f "$kudulite_image_docker_file_path" .
    docker tag $wawsimages_acr_tag_name_in_lower_case $mcr_tag_in_lower_case

    # Adding image names to a file which contains list of images that must be pushed to MCR
    echo $wawsimages_acr_tag_name_in_lower_case >> $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR
    echo $mcr_tag_in_lower_case >> $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR    
}

clean_list_of_images_to_push_to_mcr

# if KUDULITE_TYPE_TO_BUILD is empty (not specified), build all types
if [[ -z $KUDULITE_TYPE_TO_BUILD ]]; then
    build_kudulite_image "stretch"
    build_kudulite_image "buster"
    build_kudulite_image "bullseye"
    exit
fi

# else build only the specified type of kudulite image
build_kudulite_image $KUDULITE_TYPE_TO_BUILD