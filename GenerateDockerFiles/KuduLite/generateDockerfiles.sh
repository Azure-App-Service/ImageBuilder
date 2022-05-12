#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script generates Dockerfiles for KuduLiteBuild Image for Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

# Current Working Dir
declare -r ORIG_DIR=`pwd`
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Directory for Generated Docker Files
declare -r STACK_NAME="KuduLite"
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r BASE_IMAGE_REPO_NAME="$2/build"
declare -r BASE_IMAGE_VERSION_STREAM_FEED="$3"                     # Base Image Version; Oryx Version : 20190819.2
declare -r APPSVC_KUDULITE_REPO="$4"        
declare -r CONFIG_DIR="$5"                                         # ${Current_Repo}/Config
declare -r METADATA_FILE="$SYSTEM_ARTIFACTS_DIR/metadata"
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"
declare -r KUDULITE_BRANCH=$6
declare -r APP_SVC_REPO_BRANCH="${KUDULITE_BRANCH:="dev"}"
declare -r DYN_INST_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo-DynInst"
declare -r DYN_INST_REPO_BRANCH="${KUDULITE_BRANCH:="dev"}"
declare -r BULLSEYE_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo-Bullseye"
declare -r BULLSEYE_REPO_BRANCH="${KUDULITE_BRANCH:="dev"}"

function generateKuduLiteDockerFiles()
{
    # Example line:
    # 1.0 -> uses Oryx Base Image mcr.microsoft.com/oryx/build:$BASE_IMAGE_VERSION_STREAM_FEED

    # Base Image
    BASE_IMAGE_NAME="${BASE_IMAGE_REPO_NAME}:$BASE_IMAGE_VERSION_STREAM_FEED"
    CURR_VERSION_DIRECTORY="${APP_SVC_REPO_DIR}/"
    TARGET_DOCKERFILE="${CURR_VERSION_DIRECTORY}/Dockerfile"

    #Rename Dockerfile for main kudu
    mv ${CURR_VERSION_DIRECTORY}/Dockerfile-Main ${CURR_VERSION_DIRECTORY}/Dockerfile

    echo "Generating App Service Dockerfile and dependencies for image '$BASE_IMAGE_NAME' in directory '$CURR_VERSION_DIRECTORY'..."

    # Replace placeholders, changing sed delimeter since '/' is used in path
    sed -i "s|BASE_IMAGE_NAME_PLACEHOLDER|$BASE_IMAGE_NAME|g" "$TARGET_DOCKERFILE"

    # Register the generated docker files wwith metadata dir
    echo "${APP_SVC_REPO_DIR}, " > $METADATA_FILE

    echo "Done."
}

function generateKuduLiteBusterInstallsDockerFiles()
{
    # Example line:
    # 1.0 -> uses Oryx Base Image mcr.microsoft.com/oryx/github-actions-buster-$BASE_IMAGE_VERSION_STREAM_FEED

    # Base Image, eg. github-actions-buster-20200626.1
    BASE_IMAGE_NAME="${BASE_IMAGE_REPO_NAME}:github-actions-buster-$BASE_IMAGE_VERSION_STREAM_FEED"
    CURR_VERSION_DIRECTORY="${DYN_INST_REPO_DIR}/"
    TARGET_DOCKERFILE="${CURR_VERSION_DIRECTORY}/Dockerfile"

    #Rename Dockerfile for buster kudu
    mv ${CURR_VERSION_DIRECTORY}/Dockerfile-Buster ${CURR_VERSION_DIRECTORY}/Dockerfile

    echo "Generating App Service Dockerfile and dependencies for image '$BASE_IMAGE_NAME' in directory '$CURR_VERSION_DIRECTORY'..."

    # Replace placeholders, changing sed delimeter since '/' is used in path
    sed -i "s|BASE_IMAGE_NAME_PLACEHOLDER|$BASE_IMAGE_NAME|g" "$TARGET_DOCKERFILE"

    # Register the generated docker files wwith metadata dir
    echo "${DYN_INST_REPO_DIR}, " > $METADATA_FILE

    echo "Done."
}

function generateKuduLiteBullseyeInstallsDockerFiles()
{
    # Example line:
    # 1.0 -> uses Oryx Base Image mcr.microsoft.com/oryx/github-actions-bullseye-$BASE_IMAGE_VERSION_STREAM_FEED

    # Base Image, eg. github-actions-bullseye-20200626.1
    BASE_IMAGE_NAME="${BASE_IMAGE_REPO_NAME}:github-actions-bullseye-$BASE_IMAGE_VERSION_STREAM_FEED"
    CURR_VERSION_DIRECTORY="${BULLSEYE_REPO_DIR}/"
    TARGET_DOCKERFILE="${CURR_VERSION_DIRECTORY}/Dockerfile"

    #Rename Dockerfile for buster kudu
    mv ${CURR_VERSION_DIRECTORY}/Dockerfile-Bullseye ${CURR_VERSION_DIRECTORY}/Dockerfile

    echo "Generating App Service Dockerfile and dependencies for image '$BASE_IMAGE_NAME' in directory '$CURR_VERSION_DIRECTORY'..."

    # Replace placeholders, changing sed delimeter since '/' is used in path
    sed -i "s|BASE_IMAGE_NAME_PLACEHOLDER|$BASE_IMAGE_NAME|g" "$TARGET_DOCKERFILE"

    # Register the generated docker files wwith metadata dir
    echo "${BULLSEYE_REPO_DIR}, " > $METADATA_FILE

    echo "Done."
}

function pullAppSvcRepo()
{
    # KuduLite with all SDKs
    echo "Cloning App Service KuduLiteBuild Repository in $APP_SVC_REPO_DIR"
    git clone $APPSVC_KUDULITE_REPO $APP_SVC_REPO_DIR
    cd $APP_SVC_REPO_DIR
    echo "Checking out branch $APP_SVC_REPO_BRANCH"
    git checkout $APP_SVC_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $APP_SVC_REPO_DIR
    # Adding a new line break so its easy to read the logs
    echo

    # KuduLite with dynamic installs
    echo "Cloning App Service KuduLiteBuild Repository in $DYN_INST_REPO_DIR"
    git clone $APPSVC_KUDULITE_REPO $DYN_INST_REPO_DIR
    cd $DYN_INST_REPO_DIR
    echo "Checking out branch $DYN_INST_REPO_BRANCH"
    git checkout $DYN_INST_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $DYN_INST_REPO_DIR
    # Adding a new line break so its easy to read the logs
    echo

    # KuduLite with Bullseye
    echo "Cloning App Service KuduLiteBuild Repository in $BULLSEYE_REPO_DIR"
    git clone $APPSVC_KUDULITE_REPO $BULLSEYE_REPO_DIR
    cd $BULLSEYE_REPO_DIR
    echo "Checking out branch $BULLSEYE_REPO_BRANCH"
    git checkout $BULLSEYE_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $BULLSEYE_REPO_DIR
}

pullAppSvcRepo
generateKuduLiteDockerFiles
echo
generateKuduLiteBusterInstallsDockerFiles
echo
generateKuduLiteBullseyeInstallsDockerFiles