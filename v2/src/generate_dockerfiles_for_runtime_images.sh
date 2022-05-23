#!/bin/bash
# --------------------------------------------------------------------------------------------
# This script generates Dockerfiles for runtime images for Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

declare -r STACK_NAME=$1
declare -r SYSTEM_ARTIFACTS_DIR="$2"                               # drop/ - when called from devops ; ../../output - when called from local
declare -r BASE_IMAGE_REPO_NAME="$3/${STACK_NAME}"                 # mcr.microsoft.com/oryx
declare -r BASE_IMAGE_VERSION_STREAM_FEED="$4"                     # Base Image Version; Oryx Version : 20190819.2
declare -r CONFIG_DIR="$5"                                         # src/{stack_name}/
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"
declare -r STACK_VERSION_TO_GENERATE=$6

declare -r DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Summary :
# This function generates dockerfile along with its dependent files that are needed to build a runtime image
#
# Arguments :
function generate_dockerfiles_for_runtime_images()
{
    # this file contains the list of images that must be built
    local stack_versions_map_file_path="${CONFIG_DIR}/versionTemplateMap.txt"

    echo "Generating App Service Dockerfile and dependencies for :"
    echo "---------------------------------------------------------"
    while IFS=, read -r STACK_VERSION BASE_IMAGE STACK_VERSION_TEMPLATE_DIR STACK_TAGS || [[ -n $STACK_VERSION ]] || [[ -n $BASE_IMAGE ]] || [[ -n $STACK_VERSION_TEMPLATE_DIR ]] || [[ -n $STACK_TAGS ]]
    do
        if [[ -z $STACK_VERSION_TO_GENERATE || "$STACK_VERSION" == "$STACK_VERSION_TO_GENERATE" ]]; then
            # Base Image
            local base_image_name="${BASE_IMAGE_REPO_NAME}:${BASE_IMAGE}-$BASE_IMAGE_VERSION_STREAM_FEED"
            local current_version_directory="${APP_SVC_REPO_DIR}/${STACK_VERSION}"
            target_dockerfile="${current_version_directory}/Dockerfile"

            echo "$STACK_NAME $STACK_VERSION :"

            # Remove Existing Version directory, eg: GitRepo/1.0 to replace with realized files
            echo "- Removing $current_version_directory and creating an empty directory"
            rm -rf "$current_version_directory"
            mkdir -p "$current_version_directory"

            # Copying template files for a specific version of stack. (e.g for python 3.6, only files under src/python/templates/3.6 would get copied)
            cp -R ${DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED}/$STACK_NAME/templates/${STACK_VERSION_TEMPLATE_DIR}/* "$current_version_directory"

            # Copying files under <stack>/common folder.These are files common to every version of same stack (eg. python code_profiler).
            if [ -d "$DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED/$STACK_NAME/templates/common" ]; then
                echo "- Copying files which are common for every version of $STACK_NAME"
                mkdir $current_version_directory/common
                cp -R ${DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED}/$STACK_NAME/templates/common/* "$current_version_directory/common/"
            else
                echo "- There are no common files for the stack $STACK_NAME (${DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED}/$STACK_NAME/templates/common directory)"
            fi

            # Copying files under /common folder.These are files common to every stack (eg. tcpping).
            if [ "$(ls -A $DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED/$STACK_NAME/../common)" ]; then
                echo "- Copying files that are common for every stack"
                cp -R ${DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED}/$STACK_NAME/../common/* "$current_version_directory"
            fi

            # Replace placeholders, changing sed delimeter since '/' is used in path
            echo "- Replacing BASE_IMAGE_NAME_PLACEHOLDER to $base_image_name"
            sed -i "s|BASE_IMAGE_NAME_PLACEHOLDER|$base_image_name|g" "$target_dockerfile"

            echo "- Done."
            echo

        fi

    done < "$stack_versions_map_file_path"
}

generate_dockerfiles_for_runtime_images