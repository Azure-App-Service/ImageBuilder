#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script generates Dockerfiles for static site Runtime Images for Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

# Current Working Dir
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Directory for Generated Docker Files
declare -r STACK_NAME="staticsite"
declare -r SYSTEM_ARTIFACTS_DIR="$1"
#declare -r BASE_IMAGE_REPO_NAME="$2/${STACK_NAME}"                 # mcr.microsoft.com/oryx
declare -r BASE_IMAGE_VERSION_STREAM_FEED="$3"                     # Base Image Version; Oryx Version : 20190819.2
declare -r APPSVC_STATICSITE_REPO="$4/${STACK_NAME}.git"           # https://github.com/Azure-App-Service/dotnetcore.git
declare -r CONFIG_DIR="$5"                                         # ${Current_Repo}/Config
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"



function generateDockerFiles()
{
    local stackVersionsMapFilePath="${CONFIG_DIR}/${STACK_NAME}VersionTemplateMap.txt"

    # Example line:
    # 1.0 -> uses Oryx Base Image mcr.microsoft.com/oryx/dotnetcore:1.0-$BASE_IMAGE_VERSION_STREAM_FEED
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

        echo "Done."

    done < "$stackVersionsMapFilePath"
}

function pullAppSvcRepo()
{
    echo "Cloning App Service Static Site Repository in $APP_SVC_REPO_DIR"
    git clone $APPSVC_STATICSITE_REPO $APP_SVC_REPO_DIR
    echo "Cloning App Service Static Site Repository in $APP_SVC_REPO_DIR"
    cd $APP_SVC_REPO_DIR
    echo "Checking out branch $APP_SVC_REPO_BRANCH"
    git checkout $APP_SVC_REPO_BRANCH
    chmod -R 777 $APP_SVC_REPO_DIR
}

pullAppSvcRepo
generateDockerFiles
