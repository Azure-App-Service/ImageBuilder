#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script generates Dockerfiles for PHP Runtime and Debug Images for Azure App Service on Linux.
# The debug images are tagged using -xdebug suffix.
# --------------------------------------------------------------------------------------------

set -e

# Current Working Dir
declare -r ORIG_DIR=`pwd`
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Directory for Generated Docker Files
declare -r STACK_NAME="php"
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r BASE_IMAGE_REPO_NAME="$2/${STACK_NAME}"                 # mcr.microsoft.com/oryx/php
declare -r BASE_IMAGE_VERSION="$3"                                 # Base Image Version; Oryx Version : 20190819.2
declare -r APPSVC_REPO="$4/${STACK_NAME}.git"                      # https://github.com/Azure-App-Service/php.git
declare -r CONFIG_DIR="$5"                                         # ${Current_Repo}/Config
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"
declare -r APP_SVC_REPO_BRANCH="dev"

function generateDockerFiles()
{
    local stackVersionsMapFilePath="${CONFIG_DIR}/${STACK_NAME}VersionTemplateMap.txt"

    # Example line:
    # 1.0 -> uses Oryx Base Image mcr.microsoft.com/oryx/php:1.0-$BASE_IMAGE_VERSION
    while IFS=, read -r STACK_VERSION BASE_IMAGE STACK_VERSION_TEMPLATE_DIR STACK_TAGS || [[ -n $STACK_VERSION ]] || [[ -n $BASE_IMAGE ]] || [[ -n $STACK_VERSION_TEMPLATE_DIR ]] || [[ -n $STACK_TAGS ]]
    do

        # Base Image
        BASE_IMAGE_NAME="${BASE_IMAGE_REPO_NAME}:${BASE_IMAGE}-${BASE_IMAGE_VERSION}"
        CURR_VERSION_DIRECTORY="${APP_SVC_REPO_DIR}/${STACK_VERSION}"
        TARGET_DOCKERFILE="${CURR_VERSION_DIRECTORY}/Dockerfile"

        echo "Generating App Service Dockerfile and dependencies for image '$BASE_IMAGE_NAME' in directory '$CURR_VERSION_DIRECTORY'..."

        # Remove Existing Version directory, eg: GitRepo/1.0 to replace with realized files
        rm -rf "$CURR_VERSION_DIRECTORY"
        mkdir -p "$CURR_VERSION_DIRECTORY"
        cp -R ${DIR}/${STACK_VERSION_TEMPLATE_DIR}/* "$CURR_VERSION_DIRECTORY"

        # Copy common files
        cp -R ${DIR}/../common/* "$CURR_VERSION_DIRECTORY"

        # Replace placeholders, changing sed delimeter since '/' is used in path
        sed -i "s|BASE_IMAGE_NAME_PLACEHOLDER|$BASE_IMAGE_NAME|g" "$TARGET_DOCKERFILE"
        sed -i "s|VERSION_PLACEHOLDER|$BASE_IMAGE|g" "$TARGET_DOCKERFILE"
        echo "Done."

    done < "$stackVersionsMapFilePath"
}

function pullAppSvcRepo()
{
    mkdir -p $APP_SVC_REPO_DIR
    echo "Cloning App Service php Repository in $APP_SVC_REPO_DIR"
    git clone $APPSVC_REPO $APP_SVC_REPO_DIR
    cd $APP_SVC_REPO_DIR
    echo "Checking out branch $APP_SVC_REPO_BRANCH"
    git checkout $APP_SVC_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $APP_SVC_REPO_DIR
}

pullAppSvcRepo
generateDockerFiles
