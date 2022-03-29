#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script generates Dockerfiles for Go Runtime Images for Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

# Current Working Dir
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Directory for Generated Docker Files
declare -r STACK_NAME="go"
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r CONFIG_DIR="$5" # ${Current_Repo}/Config
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"

function generateDockerFiles()
{
    local stackVersionsMapFilePath="${CONFIG_DIR}/${STACK_NAME}VersionTemplateMap.txt"

    while IFS=, read -r STACK_VERSION BASE_IMAGE STACK_VERSION_TEMPLATE_DIR STACK_TAGS || [[ -n $STACK_VERSION ]] || [[ -n $BASE_IMAGE ]] || [[ -n $STACK_VERSION_TEMPLATE_DIR ]] || [[ -n $STACK_TAGS ]]
    do
        # Base Image
        CURR_VERSION_DIRECTORY="${APP_SVC_REPO_DIR}/${STACK_VERSION}"
        TARGET_DOCKERFILE="${CURR_VERSION_DIRECTORY}/Dockerfile"

        echo "Generating App Service Dockerfile and dependencies for image '$STACK_NAME-$STACK_VERSION' in directory '$CURR_VERSION_DIRECTORY'..."

        # Remove Existing Version directory, eg: GitRepo/1.0 to replace with realized files
        rm -rf "$CURR_VERSION_DIRECTORY"
        mkdir -p "$CURR_VERSION_DIRECTORY"
        cp -R ${DIR}/${STACK_VERSION_TEMPLATE_DIR}/* "$CURR_VERSION_DIRECTORY"

        # Copy common files
        cp -R ${DIR}/../common/* "$CURR_VERSION_DIRECTORY"

        echo "Done."

    done < "$stackVersionsMapFilePath"
}

generateDockerFiles
